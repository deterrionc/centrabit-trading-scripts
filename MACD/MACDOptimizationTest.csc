# MACD trading strategy optimization test 2.1.0 - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script MACDOptimizationTest;

# System Libraries
import IO;
import Time;
import Trades;
import Charts;

# Built-in Library
import "library.csh";

#############################################
# User Settings
string  EXCHANGESETTING   = "Centrabit";
string  SYMBOLSETTING     = "LTC/BTC";
integer FASTPERIODSTART   = 12;
integer FASTPERIODEND     = 12;
integer FASTPERIODSTEP    = 1;
integer SLOWPERIODSTART   = 26;
integer SLOWPERIODEND     = 26;
integer SLOWPERIODSTEP    = 1;
integer SIGNALPERIODSTART = 9;
integer SIGNALPERIODEND   = 11;
integer SIGNALPERIODSTEP  = 1;
string  RESOLSTART        = "1d";
string  RESOLEND          = "1d";
string  RESOLSTEP         = "1d";
float   AMOUNT            = 10.0;                       # The amount of buy or sell order at once
string  STARTDATETIME     = "2023-03-01 00:00:00";      # Backtest start datetime
string  ENDDATETIME       = "now";                      # Backtest end datetime
float   EXPECTANCYBASE    = 0.1;                        # expectancy base
float   FEE               = 0.002;                      # trading fee as a decimal (0.2%)
#############################################

# MACD Variables
float   fastEMA         = 0.0;
float   slowEMA         = 0.0;
float   macd            = 0.0;
float   signal          = 0.0;
float   histogram       = 0.0;

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
transaction transForTest[];

integer FASTPERIOD      = 12;
integer SLOWPERIOD      = 26;
integer SIGNALPERIOD    = 9;
string  RESOL           = "1h";

void onOwnOrderFilledTest(transaction t) {
  float amount = t.price * t.amount;
  feeTotal += t.fee;

  if (t.isAsk == false) {                # when sell order fillend
    sellTotal += amount;
  } else {                                 # when buy order fillend
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
      tradeLog = "\tLX  ";
    } else {
      profit = entryAmount - amount - t.fee - entryFee;
      tradeLog = "\tSX  ";
    }

    tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount) + "\t" + toString(profit) + "  \t" + toString(sellTotal - buyTotal - feeTotal);

    string tradeResult;
    if (profit >= 0.0 ) {
      totalWin += profit;
      winCount ++;
    } else {
      totalLoss += fabs(profit);
      lossCount ++;
    }
    tradeLogList >> tradeLog;
  } else {
    printFillLogs(t, "");
    tradeLog +=  toString(tradeNumber);
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

void onPubOrderFilledTest(transaction t) {
  if (signal == 0.0)  # Have been initialized ?
    return;

  float fastK = 2.0/(toFloat(FASTPERIOD)+1.0);
  float slowK = 2.0/(toFloat(SLOWPERIOD)+1.0);
  float singnalK = 2.0/(toFloat(SIGNALPERIOD)+1.0);

  fastEMA = EMAUpdate(t.price, fastEMA, FASTPERIOD);
  slowEMA = EMAUpdate(t.price, slowEMA, SLOWPERIOD);
  macd = fastEMA - slowEMA;
  signal = EMAUpdate(macd, signal, SIGNALPERIOD);

  float lastHistogram = histogram;
  histogram = macd - signal;

  if (histogram > 0.0 && lastHistogram <= 0.0) { # buy signal
    currentOrderId++;
    printOrderLogs(currentOrderId, "Buy", t.tradeTime, t.price, AMOUNT, "");
 
    # emulating buy order filling
    transaction filledTran;
    filledTran.id = currentOrderId;
    filledTran.marker = currentOrderId;
    filledTran.price = t.price;
    filledTran.amount = AMOUNT;
    filledTran.fee = AMOUNT * t.price * FEE * 0.01;
    filledTran.tradeTime = t.tradeTime;
    filledTran.isAsk = true;
    onOwnOrderFilledTest(filledTran);

    if (position == "flat") {
      prevPosition = "long";
    }
    position = "long";
    buyCount ++;
  }
  if (histogram < 0.0 && lastHistogram >= 0.0) { # sell signal
    currentOrderId++;
    printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT, "");

    # emulating sell order filling
    transaction filledTran;
    filledTran.id = currentOrderId;
    filledTran.marker = currentOrderId;
    filledTran.price = t.price;
    filledTran.amount = AMOUNT;
    filledTran.fee = AMOUNT * t.price * FEE * 0.01;
    filledTran.tradeTime = t.tradeTime;
    filledTran.isAsk = false;
    onOwnOrderFilledTest(filledTran);
      
    if (position == "flat") {
      prevPosition = "short";
    }
    
    position = "short";
    sellCount ++;
  }
}

float backtest() {
  if (FASTPERIOD >= SLOWPERIOD) {
    print("The slow period should be always longer than the fast period!\nPlease try again with new settings");
    return;
  }

  integer resolution = interpretResol(RESOL);
  integer testStartTime = stringToTime(STARTDATETIME, "yyyy-MM-dd hh:mm:ss");
  integer currentTime = getCurrentTime();

  bar barData[] = getTimeBars(EXCHANGESETTING, SYMBOLSETTING, testStartTime, SLOWPERIOD+SIGNALPERIOD, resolution * 60 * 1000 * 1000);
  currentOrderId = 0;

  float barPrices[];
  float macdBar[];

  # Calculating init values from the lookback data
  for (integer i = 0; i < sizeof(barData); i++) {
    barPrices >> barData[i].closePrice;

    if (i >= (FASTPERIOD-1)) {
      fastEMA = EMA(barPrices, FASTPERIOD);

      if (i >= (SLOWPERIOD-1)) {
        slowEMA = EMA(barPrices, SLOWPERIOD);
        macd = fastEMA - slowEMA;
        macdBar >> macd;

        if (i >= (SLOWPERIOD + SIGNALPERIOD -2)) {
          signal = EMA(macdBar, SIGNALPERIOD);
          histogram = macd - signal;
        }
      }   
    }
  }

  delete barData;
  delete macdBar;

  currentOrderId = 0;
  buyTotal = 0.0;
  buyCount = 0;
  sellTotal = 0.0;
  sellCount = 0;
  feeTotal = 0.0;
  prevPosition = "";

  integer cnt = sizeof(transForTest);
  integer step = resolution * 2;
  integer updateTicker = 0;
  integer msleepFlag = 0;


  integer timestampToStartLast24Hours = currentTime - 86400000000;  # 86400000000 = 24 * 3600 * 1000 * 1000
  integer lastUpdatedTimestamp = transForTest[0].tradeTime;

  integer timecounter = 0;
  delete tradeLogList;

  for (integer i = 0; i < cnt; i++) {
    if (transForTest[i].tradeTime < timestampToStartLast24Hours) {
      updateTicker = i % step;
      if (updateTicker ==0) {
        onPubOrderFilledTest(transForTest[i]);
        lastUpdatedTimestamp = transForTest[i].tradeTime;
      } 
      updateTicker ++;     
    } else {
        timecounter = transForTest[i].tradeTime - lastUpdatedTimestamp;
        if (timecounter > (resolution * 60 * 1000 * 1000)) {
          onPubOrderFilledTest(transForTest[i]);
          lastUpdatedTimestamp = transForTest[i].tradeTime;         
        }
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
          t.fee = AMOUNT*t.price*FEE * 0.01;
          t.tradeTime = transForTest[i].tradeTime;
          t.isAsk = false;
          onOwnOrderFilledTest(t);
          sellCount ++;
        } else { # buy order emulation
          printOrderLogs(currentOrderId, "Buy", transForTest[i].tradeTime, transForTest[i].price, AMOUNT, "");
          t.id = currentOrderId;
          t.marker = currentOrderId;
          t.price = transForTest[i].price;
          t.amount = AMOUNT;
          t.fee = AMOUNT*t.price*FEE * 0.01;
          t.tradeTime = transForTest[i].tradeTime;
          t.isAsk = true;
          onOwnOrderFilledTest(t);
          buyCount ++;
        }
      }
    }

    msleepFlag = i % 2000;
    if ( msleepFlag == 0) {
      msleep(30);    
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

  print("--------------------------------------------------------------------------------------------------------------------------");
  print(tradeListTitle);
  print("--------------------------------------------------------------------------------------------------------------------------");
  for (integer i = 0; i < sizeof(tradeLogList); i++) {
    print(tradeLogList[i]);
  }
  print(" ");
  print("--------------------------------------------------------------------------------------------------------------------------");
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
  # Connection Checking
  integer conTestStartTime = getCurrentTime() - 60 * 60 * 1000000;           # 1 hour before
  integer conTestEndTime = getCurrentTime();
  transaction conTestTrans[] = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, conTestStartTime, conTestEndTime);
  if (sizeof(conTestTrans) == 0) {
    print("Fetching Data failed. Please check the connection and try again later");
    exit;
  }

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

  print("======================================= Start optimization test ======================================");
  print("FASTPERIODSTART : " + toString(FASTPERIODSTART) + ", FASTPERIODEND : " + toString(FASTPERIODEND) + ", FASTPERIODSTEP : " + toString(FASTPERIODSTEP));
  print("SLOWPERIODSTART : " + toString(SLOWPERIODSTART) + ", SLOWPERIODEND : " + toString(SLOWPERIODEND) + ", SLOWPERIODSTEP : " + toString(SLOWPERIODSTEP));
  print("SIGNALPERIODSTART : " + toString(SIGNALPERIODSTART) + ", SIGNALPERIODEND : " + toString(SIGNALPERIODEND) + ", SIGNALPERIODSTEP : " + toString(SIGNALPERIODSTEP));
  print("RESOLSTART : " + RESOLSTART + ", RESOLEND : " + RESOLEND + ", RESOLSTEP : " + RESOLSTEP);
  print("AMOUNT : " + toString(AMOUNT));
  print("STARTDATETIME : " + toString(STARTDATETIME) + ", ENDDATETIME : " + toString(ENDDATETIME));
  print("=========================================================================================");
 
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
  if (testTimeLength >  31536000000000) { # maximum backtest available length is 1 year = 365  * 24 * 60 * 60 * 1000000 ns
    print("You exceeded the maximum backtest period.\nPlease try again with another STARTDATETIME setting");
    return;
  }

  print("Fetching transactions from " + STARTDATETIME + " to " + ENDDATETIME + "...");
  transForTest = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, testStartTime, testEndTime);

  clearCharts();

  for (integer i = FASTPERIODSTART; i <= FASTPERIODEND; i += FASTPERIODSTEP) {
    for (integer j = SLOWPERIODSTART; j <= SLOWPERIODEND; j += SLOWPERIODSTEP ) {
      for (integer p = SIGNALPERIODSTART; p <= SIGNALPERIODEND; p += SIGNALPERIODSTEP) {
        for (integer k = RESOLSTARTInt; k <= RESOLENDInt; k += RESOLSTEPInt) {
          paramSetNo ++;
          resolStr = toString(k) + RESOLSTARTUnitSymbol;
          paramSet = "FASTPERIOD : " + toString(i) + ", SLOWPERIOD : " + toString(j) + ", SIGNALPERIOD : " + toString(p) + ", RESOL : " + resolStr;
          FASTPERIOD = i;
          SLOWPERIOD = j;
          SIGNALPERIOD = p;
          RESOL = resolStr;
          print("------------------- Bacttest Case " + toString(paramSetNo) + " : " + paramSet + " -------------------");
          profit = backtest();
          profitResult >> profit;
          paramSetResult >> paramSet;
          msleep(100);
        }
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

  print(" ");
  print("================= Total optimization test result =================");
  print(" ");

  for (integer k=0; k< sizeof(paramSetResult); k++) {
    paramSetResult[k] = paramSetResult[k] + ", Profit : " + toString(profitResult[k]);
    print(paramSetResult[k]);
  }

  print("---------------- The optimized param set --------------");
  print(paramSetResult[best]);
  print("-------------------------------------------------------");
  print(" ");
  print("===========================================================");
  print(" ");

  return paramSetResult[best];
}

optimization();