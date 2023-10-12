# MACD trading strategy backtest 2.1.0 - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script MACDBackTest;

# System Libraries
import IO;
import Time;
import Trades;
import Charts;
import Processes;

# Built-in Library
import "library.csh";

#############################################
# User settings
string  EXCHANGESETTING = "Centrabit";
string  SYMBOLSETTING   = "LTC/BTC";
integer FASTPERIOD      = 12;
integer SLOWPERIOD      = 26;
integer SIGNALPERIOD    = 9;
float   STOPLOSSAT      = 0.05;
string  RESOL           = "30m";                    # Bar resolution
float   AMOUNT          = 1.0;                      # The amount of buy or sell order at once
string  STARTDATETIME   = "2023-07-01 00:00:00";    # Backtest start datetime
string  ENDDATETIME     = "now";                    # Backtest end datetime
float   EXPECTANCYBASE  = 0.1;                      # expectancy base
float   FEE             = 0.002;                    # trading fee as a decimal (0.2%)
#############################################

# MACD Variables
float   fastEMA         = 0.0;
float   slowEMA         = 0.0;
float   macd            = 0.0;
float   signal          = 0.0;
float   histogram       = 0.0;

# Trading Variables
string  position        = "flat";
string  prevPosition    = "";         # "", "long", "short"
integer currentOrderId  = 0;
integer buyCount        = 0;
integer sellCount       = 0;
integer winCount        = 0;
integer lossCount       = 0;
float   profitTotal     = 0.0;
float   totalWin        = 0.0;
float   totalLoss       = 0.0;
float   entryAmount     = 0.0;
float   entryFee        = 0.0;
string  tradeLogList[];

# STOP LOSS
boolean stopLossFlag    = false;
boolean stopped         = false;

# Additional needs in backtest mode
integer profitSeriesID          = 0;
string  profitSeriesColor       = "green";
string  tradeSign               = "";
transaction currentTran;
transaction entryTran;

# Starting MACD algo
setCurrentChartsExchange(EXCHANGESETTING);
setCurrentChartsSymbol(SYMBOLSETTING);

boolean stopLossTick(float price){
  if (position == "flat" || STOPLOSSAT <= 0.0) {
    return false;
  }

  float limitPrice;
  float lastOwnOrderPrice = entryTran.price;
  if (position == "long") {
    limitPrice = lastOwnOrderPrice * (1.0 - STOPLOSSAT);
    if (price < limitPrice) {
      return true;
    }
  } else if (position == "short") {
    limitPrice = lastOwnOrderPrice * (1.0 + STOPLOSSAT);
    if (price > limitPrice) {
      return true;
    }
  }
  return false;
}

void initCommonParameters() {
  if (toBoolean(getVariable("EXCHANGE"))) 
    EXCHANGESETTING = getVariable("EXCHANGE");
  if (toBoolean(getVariable("CURRNCYPAIR"))) 
    SYMBOLSETTING = getVariable("CURRNCYPAIR");
  if (toBoolean(getVariable("RESOLUTION"))) 
    RESOL = getVariable("RESOLUTION");
  if (toBoolean(getVariable("AMOUNT"))) 
    AMOUNT = toFloat(getVariable("AMOUNT"));
  if (toBoolean(getVariable("STARTDATETIME"))) 
    STARTDATETIME = getVariable("STARTDATETIME");
  if (toBoolean(getVariable("ENDDATETIME"))) 
    ENDDATETIME = getVariable("ENDDATETIME");
  if (toBoolean(getVariable("EXPECTANCYBASE"))) 
    EXPECTANCYBASE = toFloat(getVariable("EXPECTANCYBASE"));
}

void saveResultToEnv(string accProfit, string expectancy) {
  setVariable("ACCPROFIT", accProfit);
  setVariable("EXPECTANCY", expectancy);  
}

void onOwnOrderFilledTest(transaction t) {
  float amount = t.price * t.amount;

  integer isOddOrder = t.marker % 2;
  integer tradeNumber = (t.marker - 1) / 2 + 1;
  string tradeLog = "   ";

  if (isOddOrder == 0) {
    string tradeNumStr = toString(tradeNumber);
    for (integer i = 0; i < strlength(tradeNumStr); i++) {
      tradeLog += " ";
    }
    float profit;
    if (t.isAsk == false) {
      tradeSign = "LX";
      if (tradeNumber == 1) {
        profit = amount / 2.0 - entryAmount - t.fee - entryFee;
      } else {
        profit = amount - entryAmount - t.fee - entryFee;
      }
      tradeLog += "\tLX\t";
    } else {
      tradeSign = "SX";
      profit = entryAmount - amount - t.fee - entryFee;
      tradeLog += "\tSX\t";
    }

    profitTotal += profit;

    tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount / 2.0);
    tradeLogList >> tradeLog;

    if (tradeSign == "LX") {
      tradeLog = "\tSE\t";
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount / 2.0) + "\t" + toString(profit) + "  \t" + toString(profitTotal);
      tradeLogList >> tradeLog;
    }

    if (tradeSign == "SX") {
      tradeLog = "\tLE\t";
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount / 2.0) + "\t" + toString(profit) + "  \t" + toString(profitTotal);
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
    printFillLogs(t, toString(profitTotal));
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
  setCurrentChartPosition("0");

  stopLossFlag = stopLossTick(t.price);

  if (stopLossFlag) {
    currentOrderId++;

    if (position == "long") {         # Bought -> SELL
      printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT, "  (StopLoss order)");
      transaction filledTran;
      filledTran.id = currentOrderId;
      filledTran.marker = currentOrderId;
      filledTran.price = t.price;
      filledTran.amount = AMOUNT;
      filledTran.fee = AMOUNT * t.price * FEE;
      filledTran.tradeTime = t.tradeTime;
      filledTran.isAsk = false;
      onOwnOrderFilledTest(filledTran);

      position = "flat";
      prevPosition = "long";
      sellCount++;
      drawChartPointToSeries("Sell", t.tradeTime, t.price);
    }

    if (position == "short") {        # Sold -> Buy
      printOrderLogs(currentOrderId, "Buy", t.tradeTime, t.price, AMOUNT, "  (StopLoss order)");
      transaction filledTran;
      filledTran.id = currentOrderId;
      filledTran.marker = currentOrderId;
      filledTran.price = t.price;
      filledTran.amount = AMOUNT;
      filledTran.fee = AMOUNT * t.price * FEE;
      filledTran.tradeTime = t.tradeTime;
      filledTran.isAsk = true;
      onOwnOrderFilledTest(filledTran);

      position = "flat";
      prevPosition = "short";
      buyCount++;
      drawChartPointToSeries("Buy", t.tradeTime, t.price);
    }

    stopLossFlag = false;
    stopped = true;
  }

  float fastK = 2.0/(toFloat(FASTPERIOD)+1.0);
  float slowK = 2.0/(toFloat(SLOWPERIOD)+1.0);
  float singnalK = 2.0/(toFloat(SIGNALPERIOD)+1.0);

  fastEMA = EMAUpdate(t.price, fastEMA, FASTPERIOD);
  slowEMA = EMAUpdate(t.price, slowEMA, SLOWPERIOD);
  macd = fastEMA - slowEMA;
  signal = EMAUpdate(macd, signal, SIGNALPERIOD);

  float lastHistogram = histogram;
  histogram = macd - signal;

  if (histogram > 0.0 && lastHistogram <= 0.0) {        # buy signal
    if (stopped) {
      stopped = false;
    } else {
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
        filledTran.amount = AMOUNT / 2.0;
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
  if (histogram < 0.0 && lastHistogram >= 0.0) {        # sell signal
    if (stopped) {
      stopped = false;
    } else {
      currentOrderId++;
      if (currentOrderId == 1) {
        printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT / 2.0, "");
      } else {
        printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT, "");
      }

      # emulating sell order filling
      transaction filledTran;
      filledTran.id = currentOrderId;
      filledTran.marker = currentOrderId;
      filledTran.price = t.price;
      if (currentOrderId == 1) {
        filledTran.amount = AMOUNT / 2.0;
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

  drawChartPointToSeries("FastEMA", t.tradeTime, fastEMA); 
  drawChartPointToSeries("SlowEMA", t.tradeTime, slowEMA); 

  setCurrentChartPosition("1");
  drawChartPointToSeries("macd", t.tradeTime, (macd));
  drawChartPointToSeries("signal", t.tradeTime, (signal));
}

void backtest() {
  initCommonParameters();
  print("^^^^^^ MACD Backtest ( EXCHANGE : " + EXCHANGESETTING + ", CURRENCY PAIR : " + SYMBOLSETTING + ") ^^^^^^\n");

  if (FASTPERIOD >= SLOWPERIOD) {
    print("The slow period should be always longer than the fast period!\nPlease try again with new settings");
    exit;
  }
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
    exit;
  }

  print("Fetching transactions from " + STARTDATETIME + " to " + ENDDATETIME + "...");
  transaction transForTest[] = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, testStartTime, testEndTime);

  integer resolution = interpretResol(RESOL);

  bar barData[] = getTimeBars(EXCHANGESETTING, SYMBOLSETTING, testStartTime, SLOWPERIOD+SIGNALPERIOD, resolution * 60 * 1000 * 1000);

  setChartBarCount(10);
  setChartBarWidth(24 * 60 * 60 * 1000000);                                # 1 day 
  setChartTime(transForTest[0].tradeTime +  9 * 24 * 60 * 60 * 1000000);      # 9 days

  # Starting MACD algo
  setCurrentChartsExchange(EXCHANGESETTING);
  setCurrentChartsSymbol(SYMBOLSETTING);
  clearCharts();
  setChartDataTitle("MACD");
  setCurrentSeriesName("Sell");
  configureScatter(true, "red", "red", 7.0);
  setCurrentSeriesName("Buy");
  configureScatter(true, "#7dfd63", "#187206", 7.0,);
  setCurrentSeriesName("FastEMA");
  configureLine(true, "pink", 2.0);
  setCurrentSeriesName("SlowEMA");
  configureLine(true, "#00ffff", 2.0);
  setCurrentChartPosition("1");
  setChartDataTitle("MACD - " + toString(FASTPERIOD) + ", " + toString(SLOWPERIOD) + ", " + toString(SIGNALPERIOD));
  setChartYRange(0.0, 0.0); 
  setCurrentSeriesName("macd");
  configureLine(true, "blue", 2.0);
  setCurrentSeriesName("signal");
  configureLine(true, "red", 2.0);

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

  integer cnt = sizeof(transForTest);
  integer step = resolution * 2;
  integer updateTicker = 0;
  integer msleepFlag = 0;

  integer timestampToStartLast24Hours = currentTime - 86400000000;  # 86400000000 = 24 * 3600 * 1000 * 1000
  integer lastUpdatedTimestamp = transForTest[0].tradeTime;
  integer timecounter = 0;

  setChartsPairBuffering(true);

  for (integer i = 0; i < cnt; i++) {
    if (transForTest[i].tradeTime < timestampToStartLast24Hours) {
      updateTicker = i % step;
      if (updateTicker ==0) {
        onPubOrderFilledTest(transForTest[i]);
        lastUpdatedTimestamp = transForTest[i].tradeTime;
      } 
      updateTicker++;     
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
          setCurrentChartPosition("0");
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
          setCurrentChartPosition("0");
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
  
  string tradeListTitle = "\tTrade\tTime\t\t" + SYMBOLSETTING + "\t\t" + getBaseCurrencyName(SYMBOLSETTING) + "(per)\tProf" + getQuoteCurrencyName(SYMBOLSETTING) + "\t\tAcc";

  print("\n-----------------------------------------------------------------------------------------------------------------------");
  print(tradeListTitle);
  print("-----------------------------------------------------------------------------------------------------------------------");
  for (integer i = 0; i < sizeof(tradeLogList); i++) {
    print(tradeLogList[i]);
  }

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

  print("\n-----------------------------------------------------------------------------------------------------------------------");
  print("Reward-to-Risk Ratio : " + toString(rewardToRiskRatio));
  print("Win/Loss Ratio : " + toString(winLossRatio));
  print("Win Ratio  : " + toString(winRatio));
  print("Loss Ratio : " + toString(lossRatio));
  print("Expectancy : " + toString(tharpExpectancy));
  print("@ Expectancy Base: " + toString(EXPECTANCYBASE));
  print("\nResult : " + resultString);
  print("Total profit : " + toString(profitTotal));
  print("*****************************");

  saveResultToEnv(toString(profitTotal), toString(tharpExpectancy));
}

backtest();