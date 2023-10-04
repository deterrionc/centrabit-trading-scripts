# Keltner trading strategy 2.1.0 - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script Keltner;

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
integer EMALEN          = 20;                            # EMA period length
float   ATRMULTIPLIER   = 0.3;                           # ATR multiplier
integer ATRLENGTH       = 14;                            # ATR period length (must be over than 3)
string  RESOL           = "1m";                          # Bar resolution
float   AMOUNT          = 1.0;                           # The amount of buy or sell order at once
float   STOPLOSSAT      = 0.05;                          # Stoploss as fraction of price
string  logFilePath     = "c:/keltner_log_tradelist_";   # Please make sure this path any drive except C:
boolean USETRAILINGSTOP = false;
#############################################

# Trading information
float   stopVibrate     = 0.001;                         # Display the difference in oscillation stops as a fraction
string  position        = "flat";
string  prevPosition    = "";         # "", "long", "short"
float   ema             = 100.0;
float   upperBand       = 0.0;
float   lowerBand       = 0.0;
float   atr             = 0.0;
integer resolution      = interpretResol(RESOL);
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
float   baseCurrencyBalance = getAvailableBalance(EXCHANGESETTING, getBaseCurrencyName(SYMBOLSETTING));
float   quoteCurrencyBalance = getAvailableBalance(EXCHANGESETTING, getQuoteCurrencyName(SYMBOLSETTING));
float   emaPrices[];
file    logFile;
float   lastOwnOrderPrice = 0.0;

# Stop-loss and trailing stop info
float   lockedPriceForProfit  = 0.0;

string  tradeSign             = "";
boolean stopLossFlag          = false;
boolean buyStopped            = false;
boolean sellStopped           = false;
bar     atrBars[];
integer profitSeriesID        = 0;
string  profitSeriesColor     = "green";
string  tradeLogList[];
transaction transactions[];
transaction currentTran;
transaction entryTran;

void fileLog(string tradeLog) {
  logFile = fopen(logFilePath, "a");
  string logline = strreplace(tradeLog, "\t", ",");
  logline += "\n";
  fwrite(logFile, logline);
  fclose(logFile);
}

boolean invalidUpperLower() {
  float difference = (upperBand - lowerBand) / lowerBand;
  if (difference < stopVibrate) {
    return true;
  } else {
    return false;
  }
}

boolean trailingStopTick(float price) {
  if (USETRAILINGSTOP == false)
    return false;
  if (price < lowerBand) {  # if the position is in  
    if (lockedPriceForProfit == 0.0 || lockedPriceForProfit < price) {
      lockedPriceForProfit = price;
      return true;
    }
  }
  if (price > upperBand) {
    if (lockedPriceForProfit == 0.0 || lockedPriceForProfit > price) {
      lockedPriceForProfit = price;
      return true;
    }
  }
  lockedPriceForProfit = 0.0;
  return false;
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

event onPubOrderFilled(string exchange, transaction t) {
  # Check exchange and currency is correct when order filled
  if (exchange != EXCHANGESETTING || t.symbol != SYMBOLSETTING) {
    return;
  }

  updateKeltnerParams(t);
  drawChartPointToSeries("Middle", t.tradeTime, ema);
  drawChartPointToSeries("Upper", t.tradeTime, upperBand);
  drawChartPointToSeries("Lower", t.tradeTime, lowerBand);
  
  if (trailingStopTick(t.price)) {
    return;
  }

  if (invalidUpperLower()) {
    print("STOP VIBRATION");
    return;
  }
  
  stopLossFlag = toBoolean(getVariable("stopLossFlag"));

  if (stopLossFlag) {
    currentOrderId++;

    if (position == "long") {     # Bought -> Sell
      printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT, "  (StopLoss order)");
      buyStopped = true;
      sellMarket(EXCHANGESETTING, SYMBOLSETTING, AMOUNT, currentOrderId);
      position = "flat";
      prevPosition = "long";
      sellCount++;
      drawChartPointToSeries("Sell", t.tradeTime, t.price);
    }

    if (position == "short") {        # Sold -> Buy
      printOrderLogs(currentOrderId, "Buy", t.tradeTime, t.price, AMOUNT, "  (StopLoss order)");
      sellStopped = true;
      buyMarket(EXCHANGESETTING, SYMBOLSETTING, AMOUNT, currentOrderId);
      position = "flat";
      prevPosition = "short";
      buyCount++;
      drawChartPointToSeries("Buy", t.tradeTime, t.price);
    }

    stopLossFlag = false;
    setVariable("stopLossFlag", toString(stopLossFlag));
  }

  if (t.price > upperBand) {      # Sell Signal
    if (buyStopped) {  # Release buy stop when sell signal
      buyStopped = false;
    } else if (!sellStopped) {
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

        sellCount++;
        drawChartPointToSeries("Sell", t.tradeTime, t.price);
      }
    }
  }

  if (t.price < lowerBand) {      # Buy Signal
    if (sellStopped) { # Release sell stop when buy signal
      sellStopped = false;
    } else if (!buyStopped) {
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

        buyCount++;
        drawChartPointToSeries("Buy", t.tradeTime, t.price);
      }
    }
  }
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

void main() {
  # CHART SETTING
  setCurrentChartsExchange(EXCHANGESETTING);
  setCurrentChartsSymbol(SYMBOLSETTING);
  clearCharts();
  setChartTime(getCurrentTime() +  30 * 24 * 60*1000000);
  setChartDataTitle("Keltner - " + toString(EMALEN) + ", " + toString(ATRMULTIPLIER));
  setCurrentSeriesName("Sell");
  configureScatter(true, "red", "red", 7.0);
  setCurrentSeriesName("Buy");
  configureScatter(true, "#7dfd63", "#187206", 7.0,);
  setCurrentSeriesName("Failed Order");
  configureScatter(true, "grey", "black", 7.0,);
  setCurrentSeriesName("Middle");
  configureLine(true, "grey", 2.0);
  setCurrentSeriesName("Upper");
  configureLine(true, "#0095fd", 2.0);
  setCurrentSeriesName("Lower");
  configureLine(true, "#fd4700", 2.0);

  # Connection Checking
  integer conTestStartTime = getCurrentTime() - 60 * 60 * 1000000;           # 1 hour before
  integer conTestEndTime = getCurrentTime();
  transaction conTestTrans[] = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, conTestStartTime, conTestEndTime);
  integer conTestTransLength = sizeof(conTestTrans);
  if (conTestTransLength < (EMALEN + ATRLENGTH)) {
    print("Fetching Data failed. Please check the connection and try again later");
    exit;
  }

  for (integer j = 1; j <= ATRLENGTH; j++) {
    transaction tempTrans[];
    for (integer i = 1; i <= EMALEN; i++) {
      tempTrans >> conTestTrans[conTestTransLength - 1 - ATRLENGTH - EMALEN + i + j];
    }
    bar tempBar = generateBar(tempTrans);
    atrBars >> tempBar;
  }

  for (integer i = 1; i <= EMALEN; i++) {
    transaction tempTran = conTestTrans[conTestTransLength - i];
    transactions << tempTran;
    emaPrices << tempTran.price;
  }

  ema = EMA(emaPrices, EMALEN);
  atr = ATR(atrBars);
  upperBand = ema + ATRMULTIPLIER * atr;
  lowerBand = ema - ATRMULTIPLIER * atr;

  print("Initial EMA :" + toString(ema));
  print("Initial ATR :" + toString(atr));
  print("Initial keltnerUpperBand :" + toString(upperBand));
  print("Initial keltnerLowerBand :" + toString(lowerBand));

  logFilePath = logFilePath + timeToString(getCurrentTime(), "yyyy_MM_dd_hh_mm_ss") + ".csv";
  logFile = fopen(logFilePath, "a");
  fwrite(logFile, ",Trade,Time," + SYMBOLSETTING + ",," + getBaseCurrencyName(SYMBOLSETTING) + "(per),Prof" + getQuoteCurrencyName(SYMBOLSETTING) + ",Acc,\n");
  fclose(logFile);

  print("--------------   Running   -------------------");
}

main();