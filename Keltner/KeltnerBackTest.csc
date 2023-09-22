# Keltner trading strategy backtest 2.0.1 - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script KeltnerBackTest;

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
string  exchangeSetting = "Centrabit";
string  symbolSetting   = "LTC/BTC";
integer EMALEN          = 70;                     # EMA period length
float   ATRMULTIPLIER   = 3.0;                    # ATR multiplier
string  RESOL           = "30m";                  # Bar resolution
float   AMOUNT          = 1.0;                    # The amount of buy or sell order at once
string  STARTDATETIME   = "2023-06-14 00:00:00";  # Backtest start datetime
string  ENDDATETIME     = "now";                  # Backtest end datetime
float   STOPLOSSAT      = 0.05;                   # Stop loss point at percentage
boolean USETRAILINGSTOP = false;                  # Trailing stop flag
float   EXPECTANCYBASE  = 0.1;                    # expectancy base
float   FEE             = 0.002;                  # taker fee in percentage
#############################################

# Trading Variables
string  position        = "flat";
string  prevPosition    = "";                     # "", "long", "short"
float   ema             = 100.0;
float   upperBand       = 0.0;
float   lowerBand       = 0.0;
float   atr             = 0.0;
integer currentOrderId  = 0;
integer buyCount        = 0;
integer sellCount       = 0;
integer winCount          = 0;
integer lossCount         = 0;
float   buyTotal        = 0.0;
float   sellTotal       = 0.0;
float   totalWin        = 0.0;
float   totalLoss       = 0.0;
float   feeTotal        = 0.0;
float   entryAmount     = 0.0;
float   entryFee        = 0.0;
float   barPricesInEMAPeriod[];
string  tradeLogList[];
float   baseCurrencyBalance   = getAvailableBalance(exchangeSetting, getBaseCurrencyName(symbolSetting));
float   quoteCurrencyBalance  = getAvailableBalance(exchangeSetting, getQuoteCurrencyName(symbolSetting));

# Stop-loss and trailing stop info
boolean stopLossFlag            = false;
boolean buyStopped              = false;
boolean sellStopped             = false;
float   lockedPriceForProfit    = 0.0;

# Additional needs in backtest mode
float   minFillOrderPercentage  = 0.0;
float   maxFillOrderPercentage  = 0.0;
string  profitSeriesColor       = "green";
string  tradeSign               = "";
integer profitSeriesID          = 0;
bar     lastBar;
transaction transactions[];
transaction currentTran;
transaction entryTran;

void initCommonParameters() {
  if (toBoolean(getVariable("EXCHANGE"))) 
    exchangeSetting = getVariable("EXCHANGE");
  if (toBoolean(getVariable("CURRNCYPAIR"))) 
    symbolSetting = getVariable("CURRNCYPAIR");
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

void printOrderLogs(integer ID, string signal, integer time, float price, float amount, string extra) {
  print(toString(ID) + " " + signal + "\t[" + timeToString(time, "yyyy-MM-dd hh:mm:ss") + "]: " + "Price " + toString(price) + "  Amount: " + toString(amount) + extra);
}

void printFillLogs(transaction t, string totalProfit) {
  if (totalProfit == "") {
    print(toString(t.marker) + " Filled \t[" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "]: " + "Price " + toString(t.price) + "  Amount: " + toString(t.amount) + ",  Fee: " + toString(t.fee));
  } else {
    print(toString(t.marker) + " Filled \t[" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + "]: " + "Price " + toString(t.price) + "  Amount: " + toString(t.amount) + ",  Fee: " + toString(t.fee) + ",  Total profit: " + totalProfit);
  }
}

void onOwnOrderFilledTest(transaction t) {
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

boolean trailingStopTick(float price) {
  if (USETRAILINGSTOP == false)
    return false;
  if (price < lowerBand) {      # if the position is in  
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

void onPubOrderFilledTest(transaction t) {
  transactions >> t;
  currentTran = t;

  drawChartPointToSeries("Middle", t.tradeTime, ema);
  drawChartPointToSeries("Upper", t.tradeTime, upperBand);
  drawChartPointToSeries("Lower", t.tradeTime, lowerBand);

  if (trailingStopTick(t.price)) {
    return; 
  }
 
  stopLossFlag = stopLossTick(t.price);

  if (stopLossFlag) {
    currentOrderId++;

    if (position == "long") {     # Bought -> Sell
      printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT, "  (StopLoss order)");
      buyStopped = true;
      # Emulate Sell Order
      transaction filledTransaction;
      filledTransaction.id = currentOrderId;
      filledTransaction.marker = currentOrderId;
      filledTransaction.price = t.price * randomf(minFillOrderPercentage, maxFillOrderPercentage);
      filledTransaction.amount = AMOUNT;
      filledTransaction.fee = AMOUNT * t.price * FEE;
      filledTransaction.tradeTime = t.tradeTime;
      filledTransaction.isAsk = false;
      onOwnOrderFilledTest(filledTransaction);

      position = "flat";
      prevPosition = "long";

      sellCount++;
      drawChartPointToSeries("Sell", t.tradeTime, t.price);
    }

    if (position == "short") {        # Sold -> Buy
      print(toString(currentOrderId) + " buy order (" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(t.price) + "  amount: "+ toString(AMOUNT) + "  @@@ StopLoss order @@@");
      sellStopped = true;
      # Emulate Buy Order
      transaction filledTransaction;
      filledTransaction.id = currentOrderId;
      filledTransaction.marker = currentOrderId;
      filledTransaction.price = t.price + t.price * randomf((1.0-minFillOrderPercentage), (1.0-maxFillOrderPercentage));
      filledTransaction.amount = AMOUNT;
      filledTransaction.fee = AMOUNT * t.price * FEE;
      filledTransaction.tradeTime = t.tradeTime;
      filledTransaction.isAsk = true;
      onOwnOrderFilledTest(filledTransaction);

      position = "flat";
      prevPosition = "short";

      buyCount++;
      drawChartPointToSeries("Buy", t.tradeTime, t.price);
    }

    stopLossFlag = false;
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
        if (currentOrderId == 1) {
          printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT / 2.0, "");
        } else {
          printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT, "");
        }

        # Emulate Sell Order
        transaction filledTransaction;
        filledTransaction.id = currentOrderId;
        filledTransaction.marker = currentOrderId;
        filledTransaction.price = t.price * randomf(minFillOrderPercentage, maxFillOrderPercentage);
        if (currentOrderId == 1) {
          filledTransaction.amount = AMOUNT / 2.0;
          filledTransaction.fee = AMOUNT / 2.0 * t.price * FEE;
        } else {
          filledTransaction.amount = AMOUNT;
          filledTransaction.fee = AMOUNT * t.price * FEE;
        }
        filledTransaction.tradeTime = t.tradeTime;
        filledTransaction.isAsk = false;
        onOwnOrderFilledTest(filledTransaction);

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

  if (t.price < lowerBand) {          # Buy Signal
    if (sellStopped) {                # Release sell stop when buy signal
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
        if (currentOrderId == 1) {
          printOrderLogs(currentOrderId, "Buy", t.tradeTime, t.price, AMOUNT / 2.0, "");
        } else {
          printOrderLogs(currentOrderId, "Buy", t.tradeTime, t.price, AMOUNT, "");
        }
    
        # emulating buy order filling
        transaction filledTransaction;
        filledTransaction.id = currentOrderId;
        filledTransaction.marker = currentOrderId;
        filledTransaction.price = t.price + t.price * randomf((1.0-minFillOrderPercentage), (1.0-maxFillOrderPercentage));
        if (currentOrderId == 1) {
          filledTransaction.amount = AMOUNT / 2.0;
          filledTransaction.fee = AMOUNT / 2.0 * t.price * FEE;
        } else {
          filledTransaction.amount = AMOUNT;
          filledTransaction.fee = AMOUNT * t.price * FEE;
        }
        filledTransaction.tradeTime = t.tradeTime;
        filledTransaction.isAsk = true;
        onOwnOrderFilledTest(filledTransaction);

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

void onTimeOutTest() {
  if (sizeof(transactions) == 0) {
    return;
  }
  bar curBar = generateBar(transactions);
  barPricesInEMAPeriod >> curBar.closePrice;
  delete barPricesInEMAPeriod[0];

  ema = EMA(barPricesInEMAPeriod, EMALEN);
  atr = ATR(lastBar, curBar);
  upperBand = ema + ATRMULTIPLIER * atr;
  lowerBand = ema - ATRMULTIPLIER * atr;

  lastBar = curBar;
  delete transactions;
}

float backtest() {
  initCommonParameters();

  print("^^^^^^^^^^^^^^^^^ Keltner Backtest ( EXCHANGE : " + exchangeSetting + ", CURRENCY PAIR : " + symbolSetting + ") ^^^^^^^^^^^^^^^^^");
  print("");

  # Connection Checking
  integer conTestStartTime = getCurrentTime() - 60 * 60 * 1000000;           # 1 hour before
  integer conTestEndTime = getCurrentTime();
  transaction conTestTrans[] = getPubTrades(exchangeSetting, symbolSetting, conTestStartTime, conTestEndTime);
  if (sizeof(conTestTrans) == 0) {
    print("Fetching Data failed. Please check the connection and try again later");
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
  if (testTimeLength >  31536000000000) { # maximum backtest available length is 1 year = 365  * 24 * 60 * 60 * 1000000 ns
    print("You exceeded the maximum backtest period.\nPlease try again with another STARTDATETIME setting");
    return;
  }

  print("Fetching transactions from " + STARTDATETIME + " to " + ENDDATETIME + "...");
  transaction testTrans[] = getPubTrades(exchangeSetting, symbolSetting, testStartTime, testEndTime);

  integer resolution = interpretResol(RESOL);

  print("Preparing Bars in Period...");
  bar barsInPeriod[] = getTimeBars(exchangeSetting, symbolSetting, testStartTime, EMALEN, resolution * 60 * 1000 * 1000);
  integer barSize = sizeof(barsInPeriod);

  for (integer i = 0; i < barSize; i++) {
    barPricesInEMAPeriod >> barsInPeriod[i].closePrice;
  }

  setCurrentChartsExchange(exchangeSetting);
  setCurrentChartsSymbol(symbolSetting);
  clearCharts();
  setChartBarCount(10);
  setChartBarWidth(24 * 60 * 60 * 1000000);                                # 1 day 
  setChartTime(testTrans[0].tradeTime +  9 * 24 * 60 * 60 * 1000000);      # 9 days
  setChartDataTitle("Keltner - " + toString(EMALEN) + ", " + toString(ATRMULTIPLIER));

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

  float minAskOrderPrice = getOrderBookAsk(exchangeSetting, symbolSetting);
  float maxBidOrderPrice = getOrderBookBid(exchangeSetting, symbolSetting);

  order askOrders[] = getOrderBookByRangeAsks(exchangeSetting, symbolSetting, 0.0, 1.0);
  order bidOrders[] = getOrderBookByRangeBids(exchangeSetting, symbolSetting, 0.0, 1.0);


  minFillOrderPercentage = bidOrders[0].price/askOrders[sizeof(askOrders)-1].price;
  maxFillOrderPercentage = bidOrders[sizeof(bidOrders)-1].price/askOrders[0].price;
  if (AMOUNT < 10.0) {
    minFillOrderPercentage = maxFillOrderPercentage * 0.999;
  } else if (AMOUNT <100.0) {
    minFillOrderPercentage = maxFillOrderPercentage * 0.998;
  } else if (AMOUNT < 1000.0) {
    minFillOrderPercentage = maxFillOrderPercentage * 0.997;
  } else {
    minFillOrderPercentage = maxFillOrderPercentage * 0.997;
  }

  currentOrderId = 0;

  ema = EMA(barPricesInEMAPeriod, EMALEN);
  atr = ATR(barsInPeriod[barSize-2], barsInPeriod[barSize-1]);
  upperBand = ema + ATRMULTIPLIER * atr;
  lowerBand = ema - ATRMULTIPLIER * atr;

  print("Initial EMA :" + toString(ema));
  print("Initial ATR :" + toString(atr));
  print("Initial keltnerUpperBand :" + toString(upperBand));
  print("Initial keltnerLowerBand :" + toString(lowerBand));

  lastBar = barsInPeriod[barSize-1];

  print("--------------   Running   -------------------");

  integer cnt = sizeof(testTrans);
  integer step = resolution * 2;
  integer updateTicker = 0;
  integer msleepFlag = 0;

  integer timestampToStartLast24Hours = currentTime - 86400000000;  # 86400000000 = 24 * 3600 * 1000 * 1000
  integer lastUpdatedTimestamp = testTrans[0].tradeTime;

  integer timecounter = 0;  

  setChartsPairBuffering(true);

  for (integer i = 0; i < cnt; i++) {
    onPubOrderFilledTest(testTrans[i]);
    if (testTrans[i].tradeTime < timestampToStartLast24Hours) {
      updateTicker = i % step;
      if (updateTicker ==0 && i != 0) {
        onTimeOutTest();
        lastUpdatedTimestamp = testTrans[i].tradeTime;
      } 
      updateTicker ++;     
    } else {
        timecounter = testTrans[i].tradeTime - lastUpdatedTimestamp;
        if (timecounter > (resolution * 60 * 1000 * 1000)) {
          onTimeOutTest();
          lastUpdatedTimestamp = testTrans[i].tradeTime;         
        }
    }

    if (i == (cnt - 1)) {
      if (sellCount != buyCount) {
        transaction t;
        currentOrderId++;
        if (prevPosition == "long") { # sell order emulation
          print(toString(currentOrderId) + " sell order (" + timeToString(testTrans[i].tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(testTrans[i].price) + "  amount: "+ toString(AMOUNT));
          t.id = currentOrderId;
          t.marker = currentOrderId;
          t.price = testTrans[i].price * randomf(minFillOrderPercentage, maxFillOrderPercentage);
          t.amount = AMOUNT;
          t.fee = AMOUNT*t.price*FEE;
          t.tradeTime = testTrans[i].tradeTime;
          t.isAsk = false;
          onOwnOrderFilledTest(t);
          sellCount ++;
          drawChartPointToSeries("Sell", testTrans[i].tradeTime, testTrans[i].price);
        } else { # buy order emulation
          print(toString(currentOrderId) + " buy order (" + timeToString(testTrans[i].tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(testTrans[i].price) + "  amount: "+ toString(AMOUNT));
          t.id = currentOrderId;
          t.marker = currentOrderId;
          t.price = testTrans[i].price + testTrans[i].price * randomf((1.0-minFillOrderPercentage), (1.0-maxFillOrderPercentage));
          t.amount = AMOUNT;
          t.fee = AMOUNT*t.price*FEE;
          t.tradeTime = testTrans[i].tradeTime;
          t.isAsk = true;
          onOwnOrderFilledTest(t);
          buyCount ++;
          drawChartPointToSeries("Buy", testTrans[i].tradeTime, testTrans[i].price);
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

  print("");
  print(" ");

  string tradeListTitle = "\tTrade\tTime\t\t" + symbolSetting + "\t\t" + getBaseCurrencyName(symbolSetting) + "(per)\tProf" + getQuoteCurrencyName(symbolSetting) + "\t\tAcc";

  print("--------------------------------------------------------------------------------------------------------------------------");
  print(tradeListTitle);
  print("--------------------------------------------------------------------------------------------------------------------------");
  for (integer i=0; i<sizeof(tradeLogList); i++) {
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

  saveResultToEnv(toString(sellTotal - buyTotal - feeTotal), toString(tharpExpectancy));

  return sellTotal - buyTotal;
}

backtest();
