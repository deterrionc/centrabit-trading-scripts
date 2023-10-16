# Stochastic trading strategy 1.0.0 - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script Stochastic;

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
float   SELLPERCENT     = 80.0;                             # Overbought threshold possible sell signal
float   BUYPERCENT      = 20.0;                             # Oversold threshold possible buy signal
integer STOCLENGTH      = 14;                               # Stochastic Oscillator K length, Best Length is [14]
string  RESOL           = "1m";                             # Bar resolution
float   AMOUNT          = 1.0;                              # The amount of buy or sell order at once
string  logFilePath     = "c:/stochastic_log_tradelist_";   # Please make sure this path any drive except C:
#############################################

# Stochastic Variables
float stocValue = 0.0;
float stocPrices[];
transaction transactions[];

# Trading Variables
boolean canTrade        = true;
string  position        = "flat";
string  prevPosition    = "";
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
float   baseCurrencyBalance;
float   quoteCurrencyBalance;

transaction currentTran;
transaction entryTran;
integer profitSeriesID        = 0;
string  profitSeriesColor     = "green";
string  tradeSign             = "";
string  tradeLogList[];
file logFile;

void fileLog(string tradeLog) {
  logFile = fopen(logFilePath, "a");
  string logline = strreplace(tradeLog, "\t", ",");
  logline += "\n";
  fwrite(logFile, logline);
  fclose(logFile);
}

void updateStocParams(transaction t) {
  delete stocPrices[0];
  stocPrices >> t.price;
  stocValue = getStocValue(stocPrices);
}

void onPubOrderFilled(string exchange, transaction t) {
  # Check exchange and currency is correct when order filled
  if (exchange != EXCHANGESETTING || t.symbol != SYMBOLSETTING) {
    return;
  }

  if (!canTrade) {
    return;
  }

  currentTran = t;
  updateStocParams(t);

  setCurrentChartPosition("1");
  drawChartPointToSeries("Stoc", t.tradeTime, stocValue);
  drawChartPointToSeries("P1", t.tradeTime, SELLPERCENT);
  drawChartPointToSeries("P2", t.tradeTime, BUYPERCENT);
  setCurrentChartPosition("0");

  if (stocValue >= SELLPERCENT) {
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
      canTrade = false;

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

  if (stocValue <= BUYPERCENT) {
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
      canTrade = false;
  
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

  setCurrentChartPosition("0");

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


void main() {
  # Connection Checking
  integer conTestStartTime = getCurrentTime() - 60 * 60 * 1000000;           # 1 hour before
  integer conTestEndTime = getCurrentTime();
  transaction conTestTrans[] = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, conTestStartTime, conTestEndTime);
  if (sizeof(conTestTrans) < STOCLENGTH) {
    print("Fetching Data failed. Please check the connection and try again later");
    exit;
  }

  for (integer i = 0; i < STOCLENGTH; i++) {
    stocPrices << conTestTrans[sizeof(conTestTrans) - 1 - i].price;
  }

  stocValue = getStocValue(stocPrices);

  print("Initial Stochastic Oscillator K :" + toString(stocValue));
  print("--------------   Running   -------------------");

  setCurrentChartsExchange(EXCHANGESETTING);
  setCurrentChartsSymbol(SYMBOLSETTING);
  clearCharts();
  setChartBarWidth(60 * 1000000);
  setChartTime(getCurrentTime() +  30 * 24 * 60 * 1000000);
  setChartDataTitle("Stochastic");
  setCurrentSeriesName("Sell");
  configureScatter(true, "red", "red", 7.0);
  setCurrentSeriesName("Buy");
  configureScatter(true, "#7dfd63", "#187206", 7.0,);
  setCurrentSeriesName("Direction");
  configureLine(true, "green", 2.0);

  setCurrentChartPosition("1");
  setChartDataTitle("Stochastic - " + toString(STOCLENGTH));
  setChartYRange(0.0, 100.0); 
  setCurrentSeriesName("Stoc");
  configureLine(true, "blue", 1.0);
  setCurrentSeriesName("P1");
  configureLine(true, "pink", 1.0);
  setCurrentSeriesName("P2");
  configureLine(true, "pink", 1.0);

  integer now = getCurrentTime();
  logFilePath = logFilePath + timeToString(now, "yyyy_MM_dd_hh_mm_ss") + ".csv";
  logFile = fopen(logFilePath, "a");
  fwrite(logFile, ",Trade,Time," + SYMBOLSETTING + ",," + getBaseCurrencyName(SYMBOLSETTING) + "(per),Prof" + getQuoteCurrencyName(SYMBOLSETTING) + ",Acc,\n");
  fclose(logFile);

  baseCurrencyBalance = getAvailableBalance(EXCHANGESETTING, getBaseCurrencyName(SYMBOLSETTING));
  quoteCurrencyBalance = getAvailableBalance(EXCHANGESETTING, getQuoteCurrencyName(SYMBOLSETTING));

  addTimer(resolution * 10 * 1000);
}

main();

event onTimedOut(integer interval) {
  canTrade = true;
}