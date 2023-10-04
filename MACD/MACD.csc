# Bollinger Bands trading strategy 2.1.0 - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script MACD;

# System Library Import
# System Libraries
import IO;
import Time;
import Trades;
import Charts;
import Files;
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
string  RESOL           = "1m";                             # Bar resolution
float   AMOUNT          = 0.1;                              # The amount of buy or sell order at once
string logFilePath      = "c:/macd_log_";                   # Please make sure this path any drive except C:
string tradeLogListFilePath = "c:/macd_log_tradelist_";     # Please make sure this path any drive except C:
#############################################

# Trading Variables
string  position        = "flat";
string  prevPosition    = "";         # "", "long", "short"
float   fastEMA         = 0.0;
float   slowEMA         = 0.0;
float   macd            = 0.0;
float   signal          = 0.0;
float   histogram       = 0.0;
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
float   baseCurrencyBalance   = getAvailableBalance(EXCHANGESETTING, getBaseCurrencyName(SYMBOLSETTING));
float   quoteCurrencyBalance  = getAvailableBalance(EXCHANGESETTING, getQuoteCurrencyName(SYMBOLSETTING));

# Additional needs in backtest mode
float   minFillOrderPercentage = 0.0;
float   maxFillOrderPercentage = 0.0;


# STOP LOSS
boolean stopLossFlag    = false;
boolean stopped         = false;

# Starting MACD algo
setCurrentChartsExchange(EXCHANGESETTING);
setCurrentChartsSymbol(SYMBOLSETTING);

integer profitSeriesID    = 0;
string  profitSeriesColor = "green";
string  tradeSign         = "";
transaction currentTran;
transaction entryTran;

file logFile;
file tradeLogListFile;

void fileLog(string tradeLog) {
  logFile = fopen(logFilePath, "a");
  string logline = strreplace(tradeLog, "\t", ",");
  logline += "\n";
  fwrite(logFile, logline);
  fclose(logFile);
}

void main() {
  # Connection Checking
  integer conTestStartTime = getCurrentTime() - 60 * 60 * 1000000;           # 1 hour before
  integer conTestEndTime = getCurrentTime();
  transaction conTestTrans[] = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, conTestStartTime, conTestEndTime);
  if (sizeof(conTestTrans) == 0) {
    print("Fetching Data failed. Please check the connection and try again later");
    exit;
  }

  if (FASTPERIOD >= SLOWPERIOD) {
    print("The slow period should be always longer than the fast period!\nPlease try again with new settings");
    return;
  }

  integer resolution = interpretResol(RESOL);

  bar barData[] = getTimeBars(EXCHANGESETTING, SYMBOLSETTING, 0, SLOWPERIOD+SIGNALPERIOD, resolution * 60 * 1000 * 1000);

  integer now = getCurrentTime();
  logFilePath = logFilePath + timeToString(now, "yyyy_MM_dd_hh_mm_ss") + ".csv";
  logFile = fopen(logFilePath, "a");
  fwrite(logFile, "DateTime,Price,FastE MA,Slow EMA,MACD,SIGNAL,HISTOGRAM,Action\n");
  float barPrices[];
  float macdBar[];

  print("MACD initializing...");
  print("---------------------------------");
  print("Date-Time - Price - Fast EMA - Slow EMA - MACD - SIGNAL - HISTOGRAM");

  # Calculating init values from the lookback data
  for (integer i=0; i<sizeof(barData); i++) {
    barPrices >> barData[i].closePrice;

    if (i >= (FASTPERIOD-1)) {
      fastEMA = EMA(barPrices, FASTPERIOD);

      if (i < (SLOWPERIOD-1)) {
        print(timeToString(barData[i].timestamp, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(barData[i].closePrice) + "\t" + toString(fastEMA));
        fwrite(logFile, timeToString(barData[i].timestamp, "yyyy-MM-dd hh:mm:ss") + "," + toString(barData[i].closePrice) + "," + toString(fastEMA)+",0,0,0,0,\n");
      }

      if (i >= (SLOWPERIOD-1)) {
        slowEMA = EMA(barPrices, SLOWPERIOD);
        macd = fastEMA - slowEMA;
        macdBar >> macd;

        if (i < (SLOWPERIOD + SIGNALPERIOD -2)) {
          print(timeToString(barData[i].timestamp, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(barData[i].closePrice) + "\t" + toString(fastEMA) + "\t" + toString(slowEMA) + "\t" + toString(macd));
          fwrite(logFile, timeToString(barData[i].timestamp, "yyyy-MM-dd hh:mm:ss") + "," + toString(barData[i].closePrice) + "," + toString(fastEMA) + "," + toString(slowEMA) + "," + toString(macd)+",0,0,\n");
        }

        if (i >= (SLOWPERIOD + SIGNALPERIOD -2)) {
          signal = EMA(macdBar, SIGNALPERIOD);
          histogram = macd - signal;
          print(timeToString(barData[i].timestamp, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(barData[i].closePrice) + "\t" + toString(fastEMA) + "\t" + toString(slowEMA) + "\t" + toString(macd) + "\t" + toString(signal) + "\t" + toString(histogram));
          fwrite(logFile, timeToString(barData[i].timestamp, "yyyy-MM-dd hh:mm:ss") + "," + toString(barData[i].closePrice) + "," + toString(fastEMA) + "," + toString(slowEMA) + "," + toString(macd) + "," + toString(signal) + "," + toString(histogram)+",\n");
        }
      }   
    } else {
      print(timeToString(barData[i].timestamp, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(barData[i].closePrice));
      fwrite(logFile, timeToString(barData[i].timestamp, "yyyy-MM-dd hh:mm:ss") + "," + toString(barData[i].closePrice)+",0,0,0,0,0,\n");
    }
  }

  fclose(logFile);
  delete barData;
  delete macdBar;

  print("");
  print("Initial fast EMA : " + toString(fastEMA));
  print("Initial slow EMA : " + toString(slowEMA));
  print("Initial MACD : " + toString(macd));
  print("Initial SIGNAL : " + toString(signal));
  print("Initial HISTOGRAM : " + toString(histogram));
  print("");

  print("MACD running ...");
  print("---------------------------------");

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
  setCurrentSeriesName("macd");
  configureLine(true, "blue", 2.0);
  setCurrentSeriesName("signal");
  configureLine(true, "red", 2.0);

  tradeLogListFilePath = tradeLogListFilePath + timeToString(now, "yyyy_MM_dd_hh_mm_ss") + ".csv";
  tradeLogListFile = fopen(tradeLogListFilePath, "a");
  fwrite(tradeLogListFile, ",Trade,Time," + SYMBOLSETTING + ",," + getBaseCurrencyName(SYMBOLSETTING) + "(per),Prof" + getQuoteCurrencyName(SYMBOLSETTING) + ",Acc,\n");
  fclose(tradeLogListFile);

  baseCurrencyBalance = getAvailableBalance(EXCHANGESETTING, getBaseCurrencyName(SYMBOLSETTING));
  quoteCurrencyBalance = getAvailableBalance(EXCHANGESETTING, getQuoteCurrencyName(SYMBOLSETTING));

  addTimer(resolution * 60 * 1000);
}

event onPubOrderFilled(string exchange, transaction t) {
  # Check exchange and currency is correct when order filled
  if (exchange != EXCHANGESETTING || t.symbol != SYMBOLSETTING) {
    return;
  }

  setCurrentChartPosition("0");

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
      currentTran = t;

      if (currentOrderId == 1) {
        printOrderLogs(currentOrderId, "Buy", t.tradeTime, t.price, AMOUNT / 2.0, "");
        buyMarket(EXCHANGESETTING, SYMBOLSETTING, AMOUNT / 2.0, currentOrderId);
      } else {
        printOrderLogs(currentOrderId, "Buy", t.tradeTime, t.price, AMOUNT, "");
        buyMarket(EXCHANGESETTING, SYMBOLSETTING, AMOUNT, currentOrderId);
      }

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

      buyCount ++;
      drawChartPointToSeries("Buy", t.tradeTime, t.price);
    }
  }
  if (histogram < 0.0 && lastHistogram >= 0.0) {        # sell signal
    if (stopped) {
      stopped = false;
    } else {
      currentOrderId++;
      currentTran = t;

      if (currentOrderId == 1) {
        printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT / 2.0, "");
        sellMarket(EXCHANGESETTING, SYMBOLSETTING, AMOUNT / 2.0, currentOrderId);
      } else {
        printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT, "");
        sellMarket(EXCHANGESETTING, SYMBOLSETTING, AMOUNT, currentOrderId);
      }
        
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

      sellCount ++;

      drawChartPointToSeries("Sell", t.tradeTime, t.price);
    }
  }

  drawChartPointToSeries("FastEMA", t.tradeTime, fastEMA); 
  drawChartPointToSeries("SlowEMA", t.tradeTime, slowEMA); 

  setCurrentChartPosition("1");
  drawChartPointToSeries("macd", t.tradeTime, (macd));
  drawChartPointToSeries("signal", t.tradeTime, (signal));
}

event onOwnOrderFilled(string exchange, transaction t) {
  # Check exchange and currency is correct when order filled
  if (exchange != EXCHANGESETTING || t.symbol != SYMBOLSETTING) {
    return;
  }
  
  float amount = t.price * t.amount;
  feeTotal += t.fee;

  if (t.isAsk == false) {                # when sell order fillend
    sellTotal += amount;
    baseCurrencyBalance -= AMOUNT;
    quoteCurrencyBalance += amount;
  } else {                                 # when buy order fillend
    buyTotal += amount;
    baseCurrencyBalance += AMOUNT;
    quoteCurrencyBalance -= amount;
  }

  integer isOddOrder = t.marker % 2;
  integer tradeNumber = (t.marker-1) / 2 + 1;
  string tradeLog = "   ";

  setCurrentChartPosition("0");

  if (isOddOrder == 0) {
    printFillLogs(t, toString(sellTotal - buyTotal - feeTotal));
    string tradeNumStr = toString(tradeNumber);
    for (integer i=0; i<strlength(tradeNumStr); i++) {
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
    fileLog(tradeLog);

    if (tradeSign == "LX") {
      tradeLog = "\tSE\t";
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount / 2.0) + "\t" + toString(profit) + "  \t" + toString(sellTotal - buyTotal - feeTotal);
      fileLog(tradeLog);
    }

    if (tradeSign == "SX") {
      tradeLog = "\tLE\t";
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount / 2.0) + "\t" + toString(profit) + "  \t" + toString(sellTotal - buyTotal - feeTotal);
      fileLog(tradeLog);
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
    fileLog(tradeLog);

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
      fileLog(tradeLog);
    }
    if (tradeSign == "SX") {
      tradeLog = "\tLX\t";
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(t.amount / 2.0);
      fileLog(tradeLog);
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
      fileLog(tradeLog);
    } else {
      tradeLog = tradeLog + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "\t" + toString(t.price) + "\t\t" + toString(AMOUNT / 2.0);
      fileLog(tradeLog);
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

event onTimedOut(integer interval) {
  
}

main();