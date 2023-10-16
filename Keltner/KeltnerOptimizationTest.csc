# Keltner trading strategy optimization test 2.1.0 - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script KeltnerOptimizationTest;

# System Libraries
import IO;
import Time;
import Trades;
import Charts;

# Built-in Library
import "library.csh";

#############################################
# User settings
string  EXCHANGESETTING     = "Centrabit";
string  SYMBOLSETTING       = "LTC/BTC";
integer EMALENSTART         = 20;
integer EMALENEND           = 20;
integer EMALENSTEP          = 10;
float   ATRMULTIPLIERSTART  = 0.5;
float   ATRMULTIPLIEREND    = 0.5;
float   ATRMULTIPLIERSTEP   = 0.1;
integer ATRLENGTH           = 14;                      # ATR period length (must be over than 3)
string  RESOLSTART          = "30m";
string  RESOLEND            = "30m";
string  RESOLSTEP           = "30m";
float   EXPECTANCYBASE      = 0.1;                     # expectancy base
float   FEE                 = 0.002;                   # trading fee as a decimal (0.2%)s
float   AMOUNT              = 1.0;                     # The amount of buy or sell order at once
string  STARTDATETIME       = "2023-01-01 00:00:00";   # Backtest start datetime
string  ENDDATETIME         = "now";                   # Backtest end datetime
float   STOPLOSSAT          = 0.05;                    # Stoploss as fraction of price
boolean USETRAILINGSTOP     = false;
#############################################

# Keltner Variables
float   ema             = 0.0;
float   atr             = 0.0;
float   upperBand       = 0.0;
float   lowerBand       = 0.0;
float   emaPrices[];
bar     atrBars[];
transaction transactions[];

# Trading Variables
string  position        = "flat";
string  prevPosition    = "";    # "", "long", "short"
integer currentOrderId  = 0;
integer buyCount        = 0;
integer sellCount       = 0;
integer winCount        = 0;
integer lossCount       = 0;
float   buyTotal        = 0.0;
float   sellTotal       = 0.0;
float   totalWin        = 0.0;
float   totalLoss       = 0.0;
float   feeTotal        = 0.0;
float   entryAmount     = 0.0;
float   entryFee        = 0.0;
string  tradeLogList[];
float   lastPrice             = 0.0;
float   lastOwnOrderPrice     = 0.0;
transaction transForTest[];

# Stop-loss and trailing stop info
float lockedPriceForProfit = 0.0;

# Current running ema, ATRMULTIPLIER, resol
integer EMALEN          = EMALENSTART;                  # EMA period length
float   ATRMULTIPLIER   = ATRMULTIPLIERSTART;           # Standard Deviation
string  RESOL           = RESOLSTART;                   # Bar resolution

void onOwnOrderFilledTest(transaction t) {
  float amount = t.price * t.amount;
  feeTotal += t.fee;

  if (t.isAsk == false) {                   # when sell order fillend
    sellTotal += amount;
  } else {                                  # when buy order fillend
    buyTotal += amount;
  }

  integer isOddOrder = t.marker % 2;
  integer tradeNumber = (t.marker-1) / 2 + 1;
  string tradeLog = "   ";

  if (isOddOrder == 0) {
    printFillLogs(t, toString(sellTotal - buyTotal - feeTotal));
    string tradeNumStr = toString(tradeNumber);
    for (integer i = 0; i < strlength(tradeNumStr); i++) {
      tradeLog += " ";
    }
    float profit;
    if (t.isAsk == false) {
      profit = amount - entryAmount - t.fee - entryFee;
      tradeLog += "\tLX\t";
    } else {
      profit = entryAmount - amount - t.fee - entryFee;
      tradeLog += "\tSX\t";
    }

    tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount) + "\t" + toString(profit) + "  \t" + toString(sellTotal - buyTotal - feeTotal);

    string tradeResult;
    if (profit >= 0.0 ) {
      totalWin += profit;
      winCount++;
    } else {
      totalLoss += fabs(profit);
      lossCount++;
    }
    tradeLogList >> tradeLog;
  } else {
    printFillLogs(t, "");
    tradeLog += toString(tradeNumber);
    if (t.isAsk == false) {
      tradeLog += "\tSE\t";
    } else {
      tradeLog += "\tLE\t";
    }
    entryAmount = amount;
    entryFee = t.fee;
    tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(AMOUNT);
    tradeLogList >> tradeLog;
  }
}

void updateKeltnerParams(transaction t) {
  delete transactions[0];
  delete atrBars[0];
  delete emaPrices[0];

  emaPrices >> t.price;
  transactions >> t;
  bar tempBar = generateBar(transactions);
  atrBars >> tempBar;

  ema = EMA(emaPrices, EMALEN);
  atr = ATR(atrBars);
  upperBand = ema + ATRMULTIPLIER * atr;
  lowerBand = ema - ATRMULTIPLIER * atr;
}

void onPubOrderFilledTest(transaction t) {
  string signal = "";

  if (t.price > upperBand && position != "short") {
    if (prevPosition == "") {
      signal = "sell";
    } else if (position == "long") {
      signal = "sell";
    } else if (position == "flat" && prevPosition == "short") {
      signal = "sell";
    }
  }

  if (t.price < lowerBand && position != "long") {
    if (prevPosition == "") {
      signal = "buy";
    } else if (position == "short") {
      signal = "buy";
    } else if (position == "flat" && prevPosition == "long") {
      signal = "buy";
    }
  }

  if (signal == "sell") {
    currentOrderId++;
    printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT, "");

    transaction filledTran;
    filledTran.id = currentOrderId;
    filledTran.marker = currentOrderId;
    filledTran.price = t.price;
    filledTran.amount = AMOUNT;
    filledTran.fee = AMOUNT * t.price * FEE;
    filledTran.tradeTime = t.tradeTime;
    filledTran.isAsk = false;
    onOwnOrderFilledTest(filledTran);

    lastOwnOrderPrice = t.price;
    if (position == "flat" && prevPosition == "") {
      prevPosition = "short";
    }
    position = "short";
    sellCount++;
  }

  if (signal == "buy") {
    currentOrderId++;
    printOrderLogs(currentOrderId, "Buy", t.tradeTime, t.price, AMOUNT, "");

    transaction filledTran;
    filledTran.id = currentOrderId;
    filledTran.marker = currentOrderId;
    filledTran.price = t.price;
    filledTran.amount = AMOUNT;
    filledTran.fee = AMOUNT * t.price * FEE;
    filledTran.tradeTime = t.tradeTime;
    filledTran.isAsk = true;
    onOwnOrderFilledTest(filledTran);
        
    lastOwnOrderPrice = t.price;
    if (position == "flat" && prevPosition == "") {
      prevPosition = "long";
    }   
    position = "long";
    buyCount++;  
  }
}

float backtest() {
  integer resolution = interpretResol(RESOL);
  integer testStartTime = stringToTime(STARTDATETIME, "yyyy-MM-dd hh:mm:ss");
  integer currentTime = getCurrentTime();

  currentOrderId = 0;
  buyTotal = 0.0;
  buyCount = 0;
  sellTotal = 0.0;
  sellCount = 0;
  feeTotal = 0.0;
  prevPosition = "";
  delete emaPrices;
  delete atrBars;

  integer calcTestTimeStart = testStartTime - 30 * 24 * 60 * 60 * 1000000;
  transaction transForCalc[] = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, calcTestTimeStart, testStartTime);

  if (sizeof(transForCalc) < ((ATRLENGTH + EMALEN) * resolution * 2)) {
    print("Not enough transactions in the past to calculate EMA and ATR.");
    return;
  }

  transaction transCalc[];
  for (integer i = 0; i < sizeof(transForCalc); i++) {
    if (i % (resolution * 2) == 0) {
      transCalc << transForCalc[sizeof(transForCalc) - 1 - i];
    }
    if (sizeof(transCalc) > (ATRLENGTH + EMALEN)) {
      break;
    }
  }

  for (integer i = 0; i < ATRLENGTH; i++) {
    transaction tempTrans[];
    for (integer j = i; j < (i + EMALEN); j++) {
      tempTrans >> transCalc[j];
    }
    bar tempBar = generateBar(tempTrans);
    atrBars >> tempBar;
  }

  for (integer i = 0; i < EMALEN; i++) {
    transaction tempTran = transCalc[ATRLENGTH + i];
    transactions >> tempTran;
    emaPrices >> tempTran.price;
  }

  ema = EMA(emaPrices, EMALEN);
  atr = ATR(atrBars);
  upperBand = ema + ATRMULTIPLIER * atr;
  lowerBand = ema - ATRMULTIPLIER * atr;

  print("Initial EMA :" + toString(ema));
  print("Initial ATR :" + toString(atr));
  print("Initial keltnerUpperBand :" + toString(upperBand));
  print("Initial keltnerLowerBand :" + toString(lowerBand));

  integer cnt = sizeof(transForTest);
  integer step = resolution * 2;
  integer updateTicker = 0;
  integer msleepFlag = 0;

  integer timestampToStartLast24Hours = currentTime - 86400000000;  # 86400000000 = 24 * 3600 * 1000 * 1000
  integer lastUpdatedTimestamp = transForTest[0].tradeTime;

  integer timecounter = 0;
  delete tradeLogList;

  setCurrentChartsExchange(EXCHANGESETTING);
  setCurrentChartsSymbol(SYMBOLSETTING);
  clearCharts();

  for (integer i = ATRLENGTH; i < cnt; i++) {
    onPubOrderFilledTest(transForTest[i]);
    if (transForTest[i].tradeTime < timestampToStartLast24Hours) {
      updateTicker = i % step;
      if (updateTicker == 0 && i != 0) {
        updateKeltnerParams(transForTest[i]);
      } 
      updateTicker++;     
    }

    if (i == (cnt - 1)) {
      if (sellCount != buyCount) {
        transaction t;
        currentOrderId++;
        if (prevPosition == "long") { # sell order emulation
          printOrderLogs(currentOrderId, "Sell", transForTest[i].tradeTime, transForTest[i].price, AMOUNT, "");
          t.id = currentOrderId;
          t.marker = currentOrderId;
          t.price = transForTest[i].price;
          t.amount = AMOUNT;
          t.fee = AMOUNT * t.price * FEE;
          t.tradeTime = transForTest[i].tradeTime;
          t.isAsk = false;
          onOwnOrderFilledTest(t);
          sellCount++;
        } else { # buy order emulation
          printOrderLogs(currentOrderId, "Buy", transForTest[i].tradeTime, transForTest[i].price, AMOUNT, "");
          t.id = currentOrderId;
          t.marker = currentOrderId;
          t.price = transForTest[i].price;
          t.amount = AMOUNT;
          t.fee = AMOUNT * t.price * FEE;
          t.tradeTime = transForTest[i].tradeTime;
          t.isAsk = true;
          onOwnOrderFilledTest(t);
          buyCount++;
        }
      }
    }

    msleepFlag = i % 2000;
    if ( msleepFlag == 0) {
      msleep(20);
    }
  }

  float rewardToRiskRatio = totalWin / totalLoss;
  float winLossRatio = toFloat(winCount) / toFloat(lossCount);
  float winRatio = toFloat(winCount) / toFloat(winCount+lossCount);
  float lossRatio = toFloat(lossCount) / toFloat(winCount+lossCount);
  float expectancyRatio = rewardToRiskRatio * winRatio - lossRatio;

  float averageWin = totalWin / toFloat(winCount);
  float averageLoss = totalLoss / toFloat(lossCount);
  integer totalCount = winCount + lossCount;
  float winPercentage = toFloat(winCount) / toFloat(totalCount);
  float lossPercentage = toFloat(lossCount) / toFloat(totalCount);

  float tharpExpectancy = ((winPercentage * averageWin) - (lossPercentage * averageLoss) ) / (averageLoss);

  string resultString;
  if (tharpExpectancy >= EXPECTANCYBASE) {
    resultString = "PASS";
  } else {
    resultString = "FAIL";
  }

  string tradeListTitle = "\tTrade\tTime\t\t" + SYMBOLSETTING + "\t\t" + getBaseCurrencyName(SYMBOLSETTING) + "(per)\tProf" + getQuoteCurrencyName(SYMBOLSETTING) + "\t\tAcc";

  print("\n--------------------------------------------------------------------------------------------------------------------------");
  print(tradeListTitle);
  print("--------------------------------------------------------------------------------------------------------------------------");
  for (integer i = 0; i < sizeof(tradeLogList); i++) {
    print(tradeLogList[i]);
  }
  print("\n--------------------------------------------------------------------------------------------------------------------------");
  print("Reward-to-Risk Ratio : " + toString(rewardToRiskRatio));
  print("Win/Loss Ratio : " + toString(winLossRatio));
  print("Win Ratio  : " + toString(winRatio));
  print("Loss Ratio : " + toString(lossRatio));
  print("Expectancy : " + toString(tharpExpectancy));
  print("@ Expectancy Base: " + toString(EXPECTANCYBASE));
  print(" ");
  print("Result : " + resultString);
  print("Total profit : " + toString(sellTotal - buyTotal - feeTotal));
  print("*****************************");

  return sellTotal - buyTotal;
}

string optimization() {
  string paramSetResult[];
  float profitResult[];

  integer RESOLSTARTInt = toInteger(substring(RESOLSTART, 0, strlength(RESOLSTART)-1));
  integer RESOLENDInt = toInteger(substring(RESOLEND, 0, strlength(RESOLEND)-1));
  integer RESOLSTEPInt = toInteger(substring(RESOLSTEP, 0, strlength(RESOLSTEP)-1));
  string RESOLSTARTUnitSymbol = substring(RESOLSTART, strlength(RESOLSTART)-1, 1);
  string RESOLENDUnitSymbol = substring(RESOLEND, strlength(RESOLEND)-1, 1);
  string RESOLSTEPUnitSymbol = substring(RESOLSTEP, strlength(RESOLSTEP)-1, 1);

  if (RESOLSTARTUnitSymbol != RESOLENDUnitSymbol || RESOLSTARTUnitSymbol != RESOLSTEPUnitSymbol) {
    print("Unit symbols for resolutions should be equal! Please retry again.");
    return;
  }

  string paramSet = "";
  string resolStr;
  float profit;
  integer paramSetNo = 0;

  print("\n======================================= Start Optimization Test ======================================");
  print("EMALENSTART : " + toString(EMALENSTART) + ", EMALENEND : " + toString(EMALENEND) + ", EMALENSTEP : " + toString(EMALENSTEP));
  print("ATRMULTIPLIERSTART : " + toString(ATRMULTIPLIERSTART) + ", ATRMULTIPLIEREND : " + toString(ATRMULTIPLIEREND) + ", ATRMULTIPLIERSTEP : " + toString(ATRMULTIPLIERSTEP));
  print("RESOLSTART : " + RESOLSTART + ", RESOLEND : " + RESOLEND + ", RESOLSTEP : " + RESOLSTEP);
  print("AMOUNT : " + toString(AMOUNT));
  print("STARTDATETIME : " + toString(STARTDATETIME) + ", ENDDATETIME : " + toString(ENDDATETIME));
  print("=========================================================================================\n");
 
  # Fetching the historical trading data of given datatime period
  integer testStartTime = stringToTime(STARTDATETIME, "yyyy-MM-dd hh:mm:ss");
  integer testEndTime;

  integer currentTime = getCurrentTime();
  if (ENDDATETIME == "now") {
    testEndTime = currentTime;
  } else {
    testEndTime = stringToTime(ENDDATETIME, "yyyy-MM-dd hh:mm:ss");
  }

  # Checking Maximum Back Test Period
  integer testTimeLength = testEndTime - testStartTime;
  if (testTimeLength > 31536000000000) { # maximum backtest available length is 1 year = 365  * 24 * 60 * 60 * 1000000 ns
    print("You exceeded the maximum backtest period.\nPlease try again with another STARTDATETIME setting");
    return;
  }

  transForTest = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, testStartTime, testEndTime);

  for (integer i = EMALENSTART; i <= EMALENEND; i += EMALENSTEP) {
    for (float j = ATRMULTIPLIERSTART; j <= ATRMULTIPLIEREND; j += ATRMULTIPLIERSTEP ) {
      for (integer k = RESOLSTARTInt; k <= RESOLENDInt; k += RESOLSTEPInt) {
        paramSetNo++;
        resolStr = toString(k);
        resolStr = strinsert(resolStr, strlength(resolStr), RESOLSTARTUnitSymbol);
        
        paramSet = "EMALEN : ";
        paramSet = strinsert(paramSet, 8, toString(i));
        paramSet = strinsert(paramSet, strlength(paramSet)-1, ", ATRMULTIPLIER : ");
        paramSet = strinsert(paramSet, strlength(paramSet)-1, toString(j));
        paramSet = strinsert(paramSet, strlength(paramSet)-1, ", RESOL : ");
        paramSet = strinsert(paramSet, strlength(paramSet)-1, resolStr);

        EMALEN = i;
        ATRMULTIPLIER = j;
        RESOL = resolStr;

        print("------------------- Backtest Case " + toString(paramSetNo) + " : " + paramSet + " -------------------");
        profit = backtest();
        profitResult >> profit;
        paramSetResult >> paramSet;
        msleep(100);
      }
    }
  }

  integer best = 0;
  for (integer p = 0; p < sizeof(profitResult); p++) {
    float temp = profitResult[p] - profitResult[best];
    if (temp > 0.0) {
      best = p;
    }
  }

  print("\n================= Total optimization test result =================\n");

  for (integer k=0; k< sizeof(paramSetResult); k++) {
    paramSetResult[k] = strinsert(paramSetResult[k], strlength(paramSetResult[k])-1, ", Profit : ");
    paramSetResult[k] = strinsert(paramSetResult[k], strlength(paramSetResult[k])-1, toString(profitResult[k]));
    print(paramSetResult[k]);
  }

  print("---------------- The optimized param set --------------");

  print(paramSetResult[best]);

  print("-------------------------------------------------------");
  print("\n===========================================================\n");

  return paramSetResult[best];
}

optimization();