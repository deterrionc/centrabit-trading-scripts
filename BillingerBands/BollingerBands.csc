# Bollinger Bands trading strategy 2.1.0 - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script BollingerBands;

# System Libraries
import IO;
import Math;
import Strings;
import Trades;
import Time;
import Charts;
import Files;
import Processes;

# Built-in Library
import "library.csh";

#############################################
# User settings
string  EXCHANGESETTING = "Centrabit";
string  SYMBOLSETTING   = "LTC/BTC";
integer SMALEN          = 20;                       # SMA period length
float   STDDEVSETTING   = 1.0;                      # Standard Deviation
string  RESOL           = "1m";                     # Bar resolution
float   AMOUNT          = 1.0;                      # The amount of buy or sell order at once
float   STOPLOSSAT      = 0.1;                      # Stoploss as fraction of price
boolean USETRAILINGSTOP = true;
#############################################

# Trading information
string  logFilePath     = "c:/bb_log_tradelist_";   # Please make sure this path any drive except C:
string  position        = "flat";
string  prevPosition    = "";    # "", "long", "short"
float   sma             = 100.0;
float   upperBand       = 0.0;
float   lowerBand       = 0.0;
float   stddev          = 0.0;
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
float   baseCurrencyBalance;
float   quoteCurrencyBalance;
float   lastPrice       = 0.0;
float   barPriceInSMAPeriod[];

transaction currentTran;
transaction entryTran;
integer profitSeriesID        = 0;
string  profitSeriesColor     = "green";
string  tradeSign             = "";
string  tradeLogList[];
file logFile;

float getUpperLimit(float price) {
  return price * (1.0 + STOPLOSSAT);
}

float getLowerLimit(float price) {
  return price * (1.0 - STOPLOSSAT);
}

void fileLog(string tradeLog) {
  logFile = fopen(logFilePath, "a");
  string logline = strreplace(tradeLog, "\t", ",");
  logline += "\n";
  fwrite(logFile, logline);
  fclose(logFile);
}

event onPubOrderFilled(string exchange, transaction t) {
  # Check exchange and currency is correct when order filled
  if (exchange != EXCHANGESETTING || t.symbol != SYMBOLSETTING) {
    return;
  }

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
        sellMarket(EXCHANGESETTING, SYMBOLSETTING, AMOUNT / 2.0, currentOrderId);
      } else {
        printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT, "");
        sellMarket(EXCHANGESETTING, SYMBOLSETTING, AMOUNT, currentOrderId);
      }

      currentTran = t;

      if ((currentOrderId % 2) == 1) {  # if entry
        setVariable("entryPrice", toString(t.price));
      }

      setVariable("inProcess", "1");

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
        buyMarket(EXCHANGESETTING, SYMBOLSETTING, AMOUNT / 2.0, currentOrderId);
      } else {
        printOrderLogs(currentOrderId, "Buy", t.tradeTime, t.price, AMOUNT, "");
        buyMarket(EXCHANGESETTING, SYMBOLSETTING, AMOUNT, currentOrderId);
      }

      currentTran = t;
      
      if ((currentOrderId % 2) == 1) {  # if entry
        setVariable("entryPrice", toString(t.price));
      }

      setVariable("inProcess", "1");

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

event onOwnOrderFilled(string exchange, transaction t) {
  # Check exchange and currency is correct when order filled
  if (exchange != EXCHANGESETTING || t.symbol != SYMBOLSETTING) {
    return;
  }
  
  setVariable("inProcess", "0");
  float amount = t.price * t.amount;
  feeTotal += t.fee;

  if (t.isAsk == false) {                   # when sell order fillend
    sellTotal += amount;
    baseCurrencyBalance -= AMOUNT;
    quoteCurrencyBalance += amount;
  } else {                                  # when buy order filled
    buyTotal += amount;
    baseCurrencyBalance += AMOUNT;
    quoteCurrencyBalance -= amount;
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
  barPriceInSMAPeriod >> lastPrice;
  delete barPriceInSMAPeriod[0];
  sma = SMA(barPriceInSMAPeriod);
  stddev = STDDEV(barPriceInSMAPeriod, sma);
  upperBand = bollingerUpperBand(barPriceInSMAPeriod, sma, stddev, STDDEVSETTING);
  lowerBand = bollingerLowerBand(barPriceInSMAPeriod, sma, stddev, STDDEVSETTING);
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

  integer resolution = interpretResol(RESOL);

  bar barsInPeriod[] = getTimeBars(EXCHANGESETTING, SYMBOLSETTING, 0, SMALEN, resolution * 60 * 1000 * 1000);
  for (integer i = 0; i < sizeof(barsInPeriod); i++) {
    barPriceInSMAPeriod >> barsInPeriod[i].closePrice;
  }
  setCurrentChartsExchange(EXCHANGESETTING);
  setCurrentChartsSymbol(SYMBOLSETTING);
  clearCharts();
  setChartTime(getCurrentTime() +  30 * 24 * 60 * 1000000);

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

  sma = SMA(barPriceInSMAPeriod);
  stddev = STDDEV(barPriceInSMAPeriod, sma);
  upperBand = bollingerUpperBand(barPriceInSMAPeriod, sma, stddev, STDDEVSETTING);
  lowerBand = bollingerLowerBand(barPriceInSMAPeriod, sma, stddev, STDDEVSETTING);

  print("Initial SMA :" + toString(sma));
  print("Initial bollingerSTDDEV :" + toString(stddev));
  print("Initial bollingerUpperBand :" + toString(upperBand));
  print("Initial bollingerLowerBand :" + toString(lowerBand));

  lastPrice = barsInPeriod[sizeof(barsInPeriod)-1].closePrice;

  integer now = getCurrentTime();
  logFilePath = logFilePath + timeToString(now, "yyyy_MM_dd_hh_mm_ss") + ".csv";
  logFile = fopen(logFilePath, "a");
  fwrite(logFile, ",Trade,Time," + SYMBOLSETTING + ",," + getBaseCurrencyName(SYMBOLSETTING) + "(per),Prof" + getQuoteCurrencyName(SYMBOLSETTING) + ",Acc,\n");
  fclose(logFile);

  baseCurrencyBalance = getAvailableBalance(EXCHANGESETTING, getBaseCurrencyName(SYMBOLSETTING));
  quoteCurrencyBalance = getAvailableBalance(EXCHANGESETTING, getQuoteCurrencyName(SYMBOLSETTING));

  print("--------------   Running   -------------------");

  addTimer(resolution * 60 * 1000);
}

main();