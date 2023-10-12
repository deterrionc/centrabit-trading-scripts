# Bollinger Bands trading strategy backtest 2.1.0 - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script BollingerBandsOptimizationTest;

# System Libraries
import IO;
import Time;
import Trades;
import Charts;

# Built-in Library
import "library.csh";

#############################################
# User settings
string  EXCHANGESETTING = "Centrabit";
string  SYMBOLSETTING   = "LTC/BTC";
integer SMALENSTART     = 20;
integer SMALENEND       = 20;
integer SMALENSTEP      = 10;
float   STDDEVSTART     = 4.0;
float   STDDEVEND       = 4.0;
float   STDDEVSTEP      = 2.0;
string  RESOLSTART      = "30m";
string  RESOLEND        = "30m";
string  RESOLSTEP       = "5m";
float   EXPECTANCYBASE  = 0.1;                              # expectancy base
float   FEE             = 0.002;                            # trading fee as a decimal (0.2%)s
float   AMOUNT          = 1.0;                              # The amount of buy or sell order at once
string  STARTDATETIME   = "2023-07-01 00:00:00";            # Backtest start datetime
string  ENDDATETIME     = "now";                            # Backtest end datetime
float   STOPLOSSAT      = 0.05;                             # Stoploss as fraction of price
boolean USETRAILINGSTOP = false;
#############################################

# BollingerBands Variables
float   sma             = 100.0;
float   upperBand       = 0.0;
float   lowerBand       = 0.0;
float   stddev          = 0.0;
float   smaPrices[];

# Trading Variables
string  position        = "flat";
string  prevPosition    = "";                               # "", "long", "short"
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
float   lastPrice       = 0.0;
float   lastOwnOrderPrice = 0.0;

# Stop-loss and trailing stop info
float   lockedPriceForProfit = 0.0;

# Current running sma, stddev, resol
integer SMALEN          = SMALENSTART;                          # SMA period length
float   STDDEVSETTING   = STDDEVSTART;                          # Standard Deviation
string  RESOL           = RESOLSTART;                           # Bar resolution

# Drawable flag
boolean drawable = false;
transaction transForTest[];

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

boolean stopLossTick(integer timeStamp, float price) {
  if (position == "flat" || STOPLOSSAT <= 0.0)
    return false;

  float limitPrice;
  float amount;
  float filledPrice;
  if (position == "long" && price < lowerBand) {
    limitPrice = lastOwnOrderPrice * (1.0 - STOPLOSSAT);
    if (price < limitPrice) {
      currentOrderId++;
      printOrderLogs(currentOrderId, "Sell", timeStamp, price, AMOUNT, "  (StopLoss order)");

      # emulating sell order filling
      transaction t;
      t.id = currentOrderId;
      t.marker = currentOrderId;
      t.price = price;
      t.amount = AMOUNT;
      t.fee = AMOUNT * price * FEE;
      t.tradeTime = timeStamp;
      t.isAsk = false;
      onOwnOrderFilledTest(t);

      drawChartPointToSeries("Sell", timeStamp, price);
      drawChartPointToSeries("Direction", timeStamp, price); 
      sellCount++;
      position = "flat";
      return true;
    }
  } else if (position == "short" && price > upperBand) {
    limitPrice = lastOwnOrderPrice * (1.0 + STOPLOSSAT);
    if (price > limitPrice ) {
      currentOrderId++;
      printOrderLogs(currentOrderId, "Buy", timeStamp, price, AMOUNT, "  (StopLoss order)");

      # emulating buy order filling
      transaction t;
      t.id = currentOrderId;
      t.marker = currentOrderId;
      t.price = price + price;
      t.amount = AMOUNT;
      t.fee = AMOUNT * price * FEE;
      t.tradeTime = timeStamp;
      t.isAsk = true;
      onOwnOrderFilledTest(t);

      drawChartPointToSeries("Buy", timeStamp, price);
      drawChartPointToSeries("Direction", timeStamp, price); 
      buyCount++;  
      position = "flat";
      return true;
    }
  }
  return false;
}

void updateBollingerBands() {
  smaPrices >> lastPrice;
  delete smaPrices[0];

  sma = SMA(smaPrices);
  stddev = STDDEV(smaPrices, sma);
  upperBand = bollingerUpperBand(smaPrices, sma, stddev, STDDEVSETTING);
  lowerBand = bollingerLowerBand(smaPrices, sma, stddev, STDDEVSETTING);
}

void onPubOrderFilledTest(transaction t) {
  drawChartPointToSeries("Middle", t.tradeTime, sma);
  drawChartPointToSeries("Upper", t.tradeTime, upperBand);
  drawChartPointToSeries("Lower", t.tradeTime, lowerBand);
  lastPrice = t.price;

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
    # Sell oder execution
    currentOrderId++;
    printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT, "");
    # emulating sell order filling
    transaction filledTran;
    filledTran.id = currentOrderId;
    filledTran.marker = currentOrderId;
    filledTran.price = t.price;
    filledTran.amount = AMOUNT;
    filledTran.fee = AMOUNT * t.price * FEE;
    filledTran.tradeTime = t.tradeTime;
    filledTran.isAsk = false;
    onOwnOrderFilledTest(filledTran);

    # drawing sell point and porit or loss line
    drawChartPointToSeries("Sell", t.tradeTime, t.price);
    drawChartPointToSeries("Direction", t.tradeTime, t.price);
    # Update the last own order price
    lastOwnOrderPrice = t.price;
    if (position == "flat") {
      if (prevPosition == "") {
        prevPosition = "short";
      }
      position = "short";
    } else {
      position = "flat";
    }
    sellCount++;
  }
  if (signal == "buy") {
    # buy order execution
    currentOrderId++;
    printOrderLogs(currentOrderId, "Buy", t.tradeTime, t.price, AMOUNT, "");

    # emulating buy order filling
    transaction filledTran;
    filledTran.id = currentOrderId;
    filledTran.marker = currentOrderId;
    filledTran.price = t.price;
    filledTran.amount = AMOUNT;
    filledTran.fee = AMOUNT * t.price * FEE;
    filledTran.tradeTime = t.tradeTime;
    filledTran.isAsk = true;
    onOwnOrderFilledTest(filledTran);
        
    # drawing buy point and porit or loss line
    drawChartPointToSeries("Buy", t.tradeTime, t.price);
    drawChartPointToSeries("Direction", t.tradeTime, t.price);
    # Update the last own order price
    lastOwnOrderPrice = t.price;
    if (position == "flat") {
      if (prevPosition == "") {
        prevPosition = "long";
      }
      position = "long";
    } else {
      position = "flat";
    }
    buyCount++;  
  }
}

void onTimedOutTest() {
  updateBollingerBands();
}

####################################################
# The algo starts from here

float backtest() {
  currentOrderId = 0;
  buyTotal = 0.0;
  buyCount = 0;
  sellTotal = 0.0;
  sellCount = 0;
  feeTotal = 0.0;

  totalWin = 0.0;
  winCount = 0;
  totalLoss = 0.0;
  lossCount = 0;
  entryAmount = 0.0;
  entryFee = 0.0;

  delete tradeLogList;

  # print("--------------   Backtest Running   -------------------");

  integer resolution = interpretResol(RESOL);
  integer testStartTime = stringToTime(STARTDATETIME, "yyyy-MM-dd hh:mm:ss");
  integer currentTime = getCurrentTime();

  print("Preparing Bars in Period...");
  bar barsInPeriod[] = getTimeBars(EXCHANGESETTING, SYMBOLSETTING, testStartTime, SMALEN, resolution * 60 * 1000 * 1000);
  for (integer i = 0; i < sizeof(barsInPeriod); i++) {
    smaPrices >> barsInPeriod[i].closePrice;
  }

  print("Checking order book status..");
  float minAskOrderPrice = getOrderBookAsk(EXCHANGESETTING, SYMBOLSETTING);
  float maxBidOrderPrice = getOrderBookBid(EXCHANGESETTING, SYMBOLSETTING);

  currentOrderId = 0;
  buyTotal = 0.0;
  buyCount = 0;
  sellTotal = 0.0;
  sellCount = 0;
  feeTotal = 0.0;
  prevPosition = "";

  sma = SMA(smaPrices);
  stddev = STDDEV(smaPrices, sma);
  upperBand = bollingerUpperBand(smaPrices, sma, stddev, STDDEVSETTING);
  lowerBand = bollingerLowerBand(smaPrices, sma, stddev, STDDEVSETTING);

  print("Initial SMA :" + toString(sma));
  print("Initial bollingerSTDDEV :" + toString(stddev));
  print("Initial bollingerUpperBand :" + toString(upperBand));
  print("Initial bollingerLowerBand :" + toString(lowerBand));

  lastPrice = barsInPeriod[sizeof(barsInPeriod)-1].closePrice;

  integer cnt = sizeof(transForTest);
  integer step = resolution * 2;
  integer updateTicker = 0;
  integer msleepFlag = 0;

  integer timestampToStartLast24Hours = currentTime - 86400000000;  # 86400000000 = 24 * 3600 * 1000 * 1000
  integer lastUpdatedTimestamp = transForTest[0].tradeTime;

  integer timecounter = 0;

  setCurrentChartsExchange(EXCHANGESETTING);
  setCurrentChartsSymbol(SYMBOLSETTING);
  clearCharts();

  print("\nTest Progressing...\n");
  if (drawable == true) {
    setChartBarCount(10);
    setChartBarWidth(24 * 60 * 60 * 1000000);                                # 1 day 
    setChartTime(transForTest[0].tradeTime +  9 * 24 * 60 * 60 * 1000000);      # 9 days

    setChartDataTitle("BollingerBands - " + toString(SMALEN) + ", " + toString(STDDEVSETTING));

    setCurrentSeriesName("Sell");
    configureScatter(true, "red", "red", 7.0);
    setCurrentSeriesName("Buy");
    configureScatter(true, "#7dfd63", "#187206", 7.0,);
    setCurrentSeriesName("Direction");
    configureLine(true, "green", 2.0);
    setCurrentSeriesName("Middle");
    configureLine(true, "grey", 2.0);
    setCurrentSeriesName("Upper");
    configureLine(true, "#0095fd", 2.0);
    setCurrentSeriesName("Lower");
    configureLine(true, "#fd4700", 2.0);  
    
    setChartsPairBuffering(true);    
  }

  for (integer i = 0; i < cnt; i++) {
    onPubOrderFilledTest(transForTest[i]);
    if (transForTest[i].tradeTime < timestampToStartLast24Hours) {
      updateTicker = i % step;
      if (updateTicker ==0) {
        onTimedOutTest();
        lastUpdatedTimestamp = transForTest[i].tradeTime;
      }      
      updateTicker++;     
    } else {
        timecounter = transForTest[i].tradeTime - lastUpdatedTimestamp;
        if (timecounter > (resolution * 60 * 1000 * 1000)) {
          onTimedOutTest();
          lastUpdatedTimestamp = transForTest[i].tradeTime;         
        }
    }

    if (i == (cnt - 1)) {
      if (sellCount != buyCount) {
        transaction t;
        currentOrderId++;
        if (prevPosition == "long") { # sell order emulation
          if (drawable == true) {
            printOrderLogs(currentOrderId, "Sell", transForTest[i].tradeTime, transForTest[i].price, AMOUNT, "");
          }
          t.id = currentOrderId;
          t.marker = currentOrderId;
          t.price = transForTest[i].price;
          t.amount = AMOUNT;
          t.fee = AMOUNT * t.price * FEE;
          t.tradeTime = transForTest[i].tradeTime;
          t.isAsk = false;
          onOwnOrderFilledTest(t);
          sellCount++;
          if (drawable == true) {
            drawChartPointToSeries("Sell", transForTest[i].tradeTime, transForTest[i].price);
            drawChartPointToSeries("Direction", transForTest[i].tradeTime, transForTest[i].price);             
          }
        } else { # buy order emulation
          if (drawable == true) {
            printOrderLogs(currentOrderId, "Buy", transForTest[i].tradeTime, transForTest[i].price, AMOUNT, "");
          }
          t.id = currentOrderId;
          t.marker = currentOrderId;
          t.price = transForTest[i].price;
          t.amount = AMOUNT;
          t.fee = AMOUNT * t.price * FEE;
          t.tradeTime = transForTest[i].tradeTime;
          t.isAsk = true;
          onOwnOrderFilledTest(t);
          buyCount++;
          if (drawable == true) {
            drawChartPointToSeries("Buy", transForTest[i].tradeTime, transForTest[i].price);
            drawChartPointToSeries("Direction", transForTest[i].tradeTime, transForTest[i].price);             
          }
        }
      }
    }
    # delete transForTest[0];
    msleepFlag = i % 2000;
    if ( msleepFlag == 0) {
      msleep(20);
    }
  }

  # delete transForTest;

  if (drawable == true) {
    setChartsPairBuffering(false);
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

  print("");
  
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
  print("SMALENSTART : " + toString(SMALENSTART) + ", SMALENEND : " + toString(SMALENEND) + ", SMALENSTEP : " + toString(SMALENSTEP));
  print("STDDEVSTART : " + toString(STDDEVSTART) + ", STDDEVEND : " + toString(STDDEVEND) + ", STDDEVSTEP : " + toString(STDDEVSTEP));
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
  if (testTimeLength > 31536000000000) { # maximum backtest available length is 1 year = 365  * 24 * 60 * 60 * 1000000 ns
    print("You exceeded the maximum backtest period.\nPlease try again with another STARTDATETIME setting");
    return;
  }
  print("Fetching transactions from " + STARTDATETIME + " to " + ENDDATETIME + "...");
  transForTest = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, testStartTime, testEndTime);

  for (integer i = SMALENSTART; i <= SMALENEND; i += SMALENSTEP) {
    for (float j = STDDEVSTART; j <= STDDEVEND; j += STDDEVSTEP ) {
      for (integer k = RESOLSTARTInt; k <= RESOLENDInt; k += RESOLSTEPInt) {
        paramSetNo++;
        resolStr = toString(k) + RESOLSTARTUnitSymbol;
        
        paramSet = "SMALEN : " + toString(i) + ", STDDEV : " + toString(j) + ", RESOL : " + resolStr;

        SMALEN = i;
        STDDEVSETTING = j;
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
    paramSetResult[k] = paramSetResult[k] + ", Profit : " + toString(profitResult[k]);
    print(paramSetResult[k]);
  }

  print("---------------- The optimized param set --------------");
  print(paramSetResult[best]);

  print("-------------------------------------------------------");
  print("\n===========================================================\n");

  return paramSetResult[best];
}

optimization();