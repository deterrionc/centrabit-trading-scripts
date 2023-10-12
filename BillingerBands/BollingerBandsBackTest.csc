# Bollinger Bands trading strategy backtest 2.1.0 - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script BollingerBandsBackTest;

# System Libraries
import IO;
import Time;
import Trades;
import Charts;
import Processes;
import Files;

# Built-in Library
import "library.csh";

#############################################
# User settings
string  EXCHANGESETTING = "Centrabit";
string  SYMBOLSETTING   = "LTC/BTC";
integer SMALEN          = 20;                               # SMA period length
float   STDDEVSETTING   = 4.0;                              # Standard Deviation
string  RESOL           = "30m";                            # Bar resolution
float   AMOUNT          = 1.0;                              # The amount of buy or sell order at once
string  STARTDATETIME   = "2023-07-01 00:00:00";            # Backtest start datetime
string  ENDDATETIME     = "now";                            # Backtest end datetime
float   STOPLOSSAT      = 0.05;                             # Stoploss as fraction of price
float   EXPECTANCYBASE  = 0.1;                              # expectancy base
float   FEE             = 0.002;                            # trading fee as a decimal (0.2%)
boolean USETRAILINGSTOP = false;                            # Trailing stop flag
string  logFilePath     = "c:/bbtest_log_tradelist_";       # Please make sure this path any drive except C:
#############################################

# BollingerBands Variables
float   sma             = 0.0;
float   stddev          = 0.0;
float   upperBand       = 0.0;
float   lowerBand       = 0.0;
float   smaPrices[];

# Trading Variables
string  position        = "flat";
string  prevPosition    = "";    # "", "long", "short"
integer resolution      = interpretResol(RESOL);
integer currentOrderId  = 0;
integer buyCount        = 0;
integer sellCount       = 0;
integer winCount        = 0;
integer lossCount       = 0;
float   buyTotal        = 0.0;
float   sellTotal       = 0.0;
float   feeTotal        = 0.0;
float   totalWin        = 0.0;
float   totalLoss       = 0.0;
float   entryAmount     = 0.0;
float   entryFee        = 0.0;
float   lastPrice       = 0.0;
string  tradeLogList[];

# Stop-loss and trailing stop info
float   lockedPriceForProfit  = 0.0;
string  positionStoppedAt     = "";
boolean stopLossFlag          = false;
boolean buyStopped            = false;
boolean sellStopped           = false;

# Additional needs in backtest mode
integer profitSeriesID          = 0;
string  profitSeriesColor       = "green";
string  tradeSign               = "";
transaction currentTran;
transaction entryTran;

file logFile;

void onOwnOrderFilledTest(transaction t) {
  float amount = t.price * t.amount;
  feeTotal += t.fee;

  if (t.isAsk == false) {                   # when sell order fillend
    sellTotal += amount;
  } else {                                  # when buy order filled
    buyTotal += amount;
  }

  integer isOddOrder = t.marker % 2;
  integer tradeNumber = (t.marker - 1) / 2 + 1;
  string tradeLog = "   ";

  if (isOddOrder == 0) {
    printFillLogs(t, toString(sellTotal - buyTotal - feeTotal));

    string tradeNumStr = toString(tradeNumber);
    for (integer i = 0; i < strlength(tradeNumStr); i++) {
      tradeLog += " ";
    }
    float profit;
    if (t.isAsk == false) {
      tradeSign = "LX";
      profit = amount - entryAmount - t.fee - entryFee;
      tradeLog += "\tLX\t";
    } else {
      tradeSign = "SX";
      profit = entryAmount - amount - t.fee - entryFee;
      tradeLog += "\tSX\t";
    }

    tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount / 2.0);
    tradeLogList >> tradeLog;

    if (tradeSign == "LX") {
      tradeLog = "\tSE\t";
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount / 2.0) + "\t" + toString(profit) + "  \t" + toString(sellTotal - buyTotal - feeTotal);
      tradeLogList >> tradeLog;
    }

    if (tradeSign == "SX") {
      tradeLog = "\tLE\t";
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount / 2.0) + "\t" + toString(profit) + "  \t" + toString(sellTotal - buyTotal - feeTotal);
      tradeLogList >> tradeLog;
    }

    if (profit >= 0.0) {
      totalWin += profit;
      winCount++;
      if (profitSeriesColor == "red") {
        profitSeriesColor = "green";
      }
    } else {
      totalLoss += fabs(profit);
      lossCount++;
      if (profitSeriesColor == "green") {
        profitSeriesColor = "red";
      }
    }

    profitSeriesID++;
    setCurrentSeriesName("Direction" + toString(profitSeriesID));
    configureLine(false, profitSeriesColor, 2.0);
    drawChartPoint(entryTran.tradeTime, entryTran.price);
    drawChartPoint(currentTran.tradeTime, currentTran.price);
    entryTran = currentTran;
  } else {
    printFillLogs(t, "");

    if (tradeSign == "LX") {
      tradeLog = "\tSX\t";
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount / 2.0);
      tradeLogList >> tradeLog;
    }
    if (tradeSign == "SX") {
      tradeLog = "\tLX\t";
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount / 2.0);
      tradeLogList >> tradeLog;
    }

    tradeLog = "   ";  
    tradeLog += toString(tradeNumber);
    if (t.isAsk == false) {
      tradeSign = "SE";
      tradeLog += "\tSE\t";
    } else {
      tradeSign = "LE";
      tradeLog += "\tLE\t";
    }
    entryAmount = amount;
    entryFee = t.fee;

    if (tradeSign == "SE") {
      if (currentTran.price > entryTran.price) {
        profitSeriesColor = "green";
      } else {
        profitSeriesColor = "red";
      }
    }

    if (tradeSign == "LE") {
      if (currentTran.price > entryTran.price) {
        profitSeriesColor = "red";
      } else {
        profitSeriesColor = "green";
      }
    }

    if (tradeNumber == 1) {
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(AMOUNT / 2.0);
      tradeLogList >> tradeLog;
    } else {
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(AMOUNT / 2.0);
      tradeLogList >> tradeLog;
    }

    if (tradeNumber > 1) {
      profitSeriesID++;
      setCurrentSeriesName("Direction" + toString(profitSeriesID));
      configureLine(false, profitSeriesColor, 2.0);
      drawChartPoint(entryTran.tradeTime, entryTran.price);
      drawChartPoint(currentTran.tradeTime, currentTran.price);
    }
    
    entryTran = currentTran;
  }
}

void onPubOrderFilledTest(transaction t) {
  currentTran = t;
  drawChartPointToSeries("Middle", t.tradeTime, sma);
  drawChartPointToSeries("Upper", t.tradeTime, upperBand);
  drawChartPointToSeries("Lower", t.tradeTime, lowerBand);
  lastPrice = t.price;

  if (t.price > upperBand) {      # Sell Signal
    boolean sellSignal = false;
    if (position == "long") {
      sellSignal = true;
    } else if (position == "flat") {
      if (prevPosition == "") {
        sellSignal = true;
      }
      if (prevPosition == "short") {
        sellSignal = true;
      }
    }

    if (sellSignal) {
      currentOrderId++;

      if (currentOrderId == 1) {
        printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT / 2.0, "");
      } else {
        printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT, "");
      }

      # Emulate Sell Order
      transaction filledTran;
      filledTran.id = currentOrderId;
      filledTran.marker = currentOrderId;
      filledTran.price = t.price;
      if (currentOrderId == 1) {
        filledTran.amount = AMOUNT;
        filledTran.fee = AMOUNT / 2.0 * t.price * FEE;
      } else {
        filledTran.amount = AMOUNT;
        filledTran.fee = AMOUNT * t.price * FEE;
      }
      filledTran.tradeTime = t.tradeTime;
      filledTran.isAsk = false;
      onOwnOrderFilledTest(filledTran);

      if (position == "flat") {
        if (prevPosition == "") {
          prevPosition = "short";
        }
        position = "short";
        prevPosition = "flat";
      } else {
        position = "flat";
        prevPosition = "long";
      }

      sellCount++;
      drawChartPointToSeries("Sell", t.tradeTime, t.price);
    }
  }

  if (t.price < lowerBand) {      # Buy Signal
    boolean buySignal = false;
    if (position == "short") {
      buySignal = true;
    } else if (position == "flat") {
      if (prevPosition == "") {
        buySignal = true;
      }
      if (prevPosition == "long") {
        buySignal = true;
      }
    }

    if (buySignal) {
      currentOrderId++;
      if (currentOrderId == 1) {
        printOrderLogs(currentOrderId, "Buy", t.tradeTime, t.price, AMOUNT / 2.0, "");
      } else {
        printOrderLogs(currentOrderId, "Buy", t.tradeTime, t.price, AMOUNT, "");
      }

      # emulating buy order filling
      transaction filledTran;
      filledTran.id = currentOrderId;
      filledTran.marker = currentOrderId;
      filledTran.price = t.price;
      if (currentOrderId == 1) {
        filledTran.amount = AMOUNT;
        filledTran.fee = AMOUNT / 2.0 * t.price * FEE;
      } else {
        filledTran.amount = AMOUNT;
        filledTran.fee = AMOUNT * t.price * FEE;
      }
      filledTran.tradeTime = t.tradeTime;
      filledTran.isAsk = true;
      onOwnOrderFilledTest(filledTran);

      if (position == "flat") {
        if (prevPosition == "") {
          prevPosition = "long";
        }
        position = "long";
        prevPosition = "flat";
      } else {
        position = "flat";
        prevPosition = "short";
      }

      buyCount++;
      drawChartPointToSeries("Buy", t.tradeTime, t.price);
    }
  }
}

void onTimeOutTest() {
  smaPrices >> lastPrice;
  delete smaPrices[0];

  sma = SMA(smaPrices);
  stddev = STDDEV(smaPrices, sma);
  upperBand = bollingerUpperBand(smaPrices, sma, stddev, STDDEVSETTING);
  lowerBand = bollingerLowerBand(smaPrices, sma, stddev, STDDEVSETTING);
}

void backtest() {
  print("^^^^^^^^^ BollingerBands Backtest ( EXCHANGE : " + EXCHANGESETTING + ", CURRENCY PAIR : " + SYMBOLSETTING + ") ^^^^^^^^^\n");

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
  if (testTimeLength > 365 * 24 * 60 * 60 * 1000000) { # Max 1 year
    print("You exceeded the maximum backtest period.\nPlease try again with another STARTDATETIME setting");
    return;
  }

  print("Fetching transactions from " + STARTDATETIME + " to " + ENDDATETIME + "...");

  transaction transForTest[] = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, testStartTime, testEndTime);
  if (sizeof(transForTest) == 0) {
    print("Fetching Data failed. Please check the connection and try again later");
    exit;
  }

  print("Preparing Bars in Period...");
  bar barsInPeriod[] = getTimeBars(EXCHANGESETTING, SYMBOLSETTING, testStartTime, SMALEN, resolution * 60 * 1000 * 1000);
  for (integer i = 0; i < sizeof(barsInPeriod); i++) {
    smaPrices >> barsInPeriod[i].closePrice;
  }

  setCurrentChartsExchange(EXCHANGESETTING);
  setCurrentChartsSymbol(SYMBOLSETTING);
  clearCharts();
  setChartBarCount(10);
  setChartBarWidth(24 * 60 * 60 * 1000000);                                # 1 day 
  setChartTime(transForTest[0].tradeTime +  9 * 24 * 60 * 60 * 1000000);      # 9 days
  setChartDataTitle("BollingerBands - " + toString(SMALEN) + ", " + toString(STDDEVSETTING));
  setCurrentSeriesName("Sell");
  configureScatter(true, "red", "red", 7.0);
  setCurrentSeriesName("Buy");
  configureScatter(true, "#7dfd63", "#187206", 7.0,);
  setCurrentSeriesName("Middle");
  configureLine(true, "grey", 2.0);
  setCurrentSeriesName("Upper");
  configureLine(true, "#0095fd", 2.0);
  setCurrentSeriesName("Lower");
  configureLine(true, "#fd4700", 2.0);  

  sma = SMA(smaPrices);
  stddev = STDDEV(smaPrices, sma);
  upperBand = bollingerUpperBand(smaPrices, sma, stddev, STDDEVSETTING);
  lowerBand = bollingerLowerBand(smaPrices, sma, stddev, STDDEVSETTING);
  lastPrice = barsInPeriod[sizeof(barsInPeriod)-1].closePrice;

  print("Initial SMA :" + toString(sma));
  print("Initial bollingerSTDDEV :" + toString(stddev));
  print("Initial bollingerUpperBand :" + toString(upperBand));
  print("Initial bollingerLowerBand :" + toString(lowerBand));
  print("--------------   Running   -------------------");

  integer cnt = sizeof(transForTest);
  integer step = resolution * 2;
  integer updateTicker = 0;
  integer msleepFlag = 0;
  integer timestampToStartLast24Hours = currentTime - 86400000000;  # 86400000000 = 24 * 3600 * 1000 * 1000
  integer lastUpdatedTimestamp = transForTest[0].tradeTime;
  integer timecounter = 0;

  setChartsPairBuffering(true);

  currentOrderId = 0;

  for (integer i = 0; i < cnt; i++) {
    onPubOrderFilledTest(transForTest[i]);
    if (transForTest[i].tradeTime < timestampToStartLast24Hours) {
      updateTicker = i % step;
      if (updateTicker == 0) {
        onTimeOutTest();
        lastUpdatedTimestamp = transForTest[i].tradeTime;
      } 
      updateTicker++;     
    } else {
      timecounter = transForTest[i].tradeTime - lastUpdatedTimestamp;
      if (timecounter > (resolution * 60 * 1000 * 1000)) {
        onTimeOutTest();
        lastUpdatedTimestamp = transForTest[i].tradeTime;         
      }
    }

    if (i == (cnt - 1)) {
      if (sellCount != buyCount) {
        transaction t;
        currentOrderId++;
        if (prevPosition == "long") {
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
          drawChartPointToSeries("Sell", transForTest[i].tradeTime, transForTest[i].price);
        } else {
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
          drawChartPointToSeries("Buy", transForTest[i].tradeTime, transForTest[i].price);
        }
      }
    }

    msleepFlag = i % 2000;
    if ( msleepFlag == 0) {
      msleep(20);    
    }
  }

  setChartsPairBuffering(false);

  integer totalCount = winCount + lossCount;
  float rewardToRiskRatio = totalWin / totalLoss;
  float winLossRatio = toFloat(winCount) / toFloat(lossCount);
  float winRatio = toFloat(winCount) / toFloat(totalCount);
  float lossRatio = toFloat(lossCount) / toFloat(totalCount);
  float averageWin = totalWin / toFloat(winCount);
  float averageLoss = totalLoss / toFloat(lossCount);
  float tharpExpectancy = ((winRatio * averageWin) - (lossRatio * averageLoss) ) / (averageLoss);

  string resultString;
  if (tharpExpectancy >= EXPECTANCYBASE) {
    resultString = "PASS";
  } else {
    resultString = "FAIL";
  }

  string tradeListTitle = "\tTrade\tTime\t\t" + SYMBOLSETTING + "\t\t" + getBaseCurrencyName(SYMBOLSETTING) + "(per)\tProf" + getQuoteCurrencyName(SYMBOLSETTING) + "\t\tAcc";

  print("\n\n-----------------------------------------------------------------------------------------------------------------------");
  print(tradeListTitle);
  print("-----------------------------------------------------------------------------------------------------------------------");

  integer now = getCurrentTime();
  logFilePath = logFilePath + timeToString(now, "yyyy_MM_dd_hh_mm_ss") + ".csv";
  logFile = fopen(logFilePath, "a");
  fwrite(logFile, ",Trade,Time," + SYMBOLSETTING + ",," + getBaseCurrencyName(SYMBOLSETTING) + "(per),Prof" + getQuoteCurrencyName(SYMBOLSETTING) + ",Acc,\n");

  string logline;
  for (integer i = 0; i < sizeof(tradeLogList); i++) {
    print(tradeLogList[i]);
    logline = strreplace(tradeLogList[i], "\t", ",");
    logline += "\n";
    fwrite(logFile, logline);
  }
  fclose(logFile);

  print("-----------------------------------------------------------------------------------------------------------------------\n");
  print("Reward-to-Risk Ratio : " + toString(rewardToRiskRatio));
  print("Win/Loss Ratio : " + toString(winLossRatio));
  print("Win Ratio  : " + toString(winRatio));
  print("Loss Ratio : " + toString(lossRatio));
  print("Expectancy : " + toString(tharpExpectancy));
  print("@ Expectancy Base: " + toString(EXPECTANCYBASE));
  print("\nResult : " + resultString);
  print("Total profit : " + toString(sellTotal - buyTotal - feeTotal));
  print("*****************************");

  return;
}

backtest();