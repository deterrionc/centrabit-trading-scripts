# RSI (Relatvie Strengh Index) trading strategy backtest - Copyright(C) 2023 Centrabit.com ( Author: smartalina0915@gmail.com )

# Script Name
script RSIBackTest;

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
string  RESOL           = "1h";                    # Bar resolution
string  STARTDATETIME   = "2023-03-01 00:00:00";   # Backtest start datetime
string  ENDDATETIME     = "now";                   # Backtest end datetime
integer PERIOD          = 14;
float   STOPLOSSAT      = 0.05;
float   AMOUNT          = 1.0;                     # The amount of buy or sell order at once
float   EXPECTANCYBASE  = 0.1;                     # expectancy base
float   FEE             = 0.002;                   # taker fee in percentage
#############################################

# Trading Variables
float   avgGain         = 0.0;
float   avgLoss         = 0.0;
float   lastPrice       = 0.0;
float   priceChange     = 0.0;
float   gain            = 0.0;
float   loss            = 0.0;
float   rs              = 0.0;
float   rsi             = 100.0;
string  position        = "flat";
string  prevPosition    = "";         # "", "long", "short"
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

integer profitSeriesID = 0;
string profitSeriesColor = "green";
transaction currentTran;
transaction entryTran;

# STOP LOSS
boolean stopLossFlag    = false;
boolean stopped         = false;

file logFile;

setCurrentChartsExchange(EXCHANGESETTING);
setCurrentChartsSymbol(SYMBOLSETTING);

boolean stopLossTick(float price){
  if (position == "flat" || STOPLOSSAT <= 0.0)
    return false;

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
    print(toString(t.marker) + " filled (" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + toString(t.price) + " * " + toString(t.amount) + ",  fee: " + toString(t.fee) + ",  Total profit: " + toString(sellTotal - buyTotal - feeTotal));
    string tradeNumStr = toString(tradeNumber);
    for (integer i=0; i<strlength(tradeNumStr); i++) {
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
      totalWin+= profit;
      winCount++;
      if (profitSeriesColor=="red") {
        profitSeriesColor="green";
      }
    } else {
      totalLoss+= fabs(profit);
      lossCount++;
      if (profitSeriesColor == "green") {
        profitSeriesColor="red";
      }
    }
    tradeLogList >> tradeLog;

    profitSeriesID++;
    setCurrentChartPosition("0");
    setCurrentSeriesName("Direction" + toString(profitSeriesID));
    configureLine(false, profitSeriesColor, 2.0);
    drawChartPoint(entryTran.tradeTime, entryTran.price);
    drawChartPoint(currentTran.tradeTime, currentTran.price);
    entryTran = currentTran;
  } else {
    print(toString(t.marker) + " filled (" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + toString(t.price) + " * " + toString(t.amount) + ",  fee: " + toString(t.fee));
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

    setCurrentChartPosition("0");
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
      print(toString(currentOrderId) + " sell order (" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(t.price) + "  amount: "+ toString(AMOUNT) + "  @@@ StopLoss order @@@");
      transaction filledTran;
      filledTran.id = currentOrderId;
      filledTran.marker = currentOrderId;
      filledTran.price = t.price * randomf(minFillOrderPercentage, maxFillOrderPercentage);
      filledTran.amount = AMOUNT;
      filledTran.fee = AMOUNT * t.price * FEE * 0.01;
      filledTran.tradeTime = t.tradeTime;
      filledTran.isAsk = false;
      onOwnOrderFilledTest(filledTran);

      position = "flat";
      prevPosition = "long";

      sellCount ++;
      drawChartPointToSeries("Sell", t.tradeTime, t.price);
    }

    if (position == "short") {        # Sold -> Buy
      print(toString(currentOrderId) + " buy order (" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(t.price) + "  amount: "+ toString(AMOUNT) + "  @@@ StopLoss order @@@");
      transaction filledTran;
      filledTran.id = currentOrderId;
      filledTran.marker = currentOrderId;
      filledTran.price = t.price + t.price * randomf((1.0-minFillOrderPercentage), (1.0-maxFillOrderPercentage));
      filledTran.amount = AMOUNT;
      filledTran.fee = AMOUNT * t.price * FEE * 0.01;
      filledTran.tradeTime = t.tradeTime;
      filledTran.isAsk = true;
      onOwnOrderFilledTest(filledTran);

      position = "flat";
      prevPosition = "short";

      buyCount ++;
      drawChartPointToSeries("Buy", t.tradeTime, t.price);
    }

    stopLossFlag = false;
    stopped = true;
  }

  priceChange = t.price - lastPrice;
  gain = 0.0;
  loss = 0.0;

  if (priceChange > 0.0) {
    gain = priceChange;
  }
  if (priceChange < 0.0) {
    loss = fabs(priceChange);
  }

  avgGain = ((avgGain * toFloat(PERIOD-1)) + gain) / toFloat(PERIOD);
  avgLoss = ((avgLoss * toFloat(PERIOD-1)) + loss) / toFloat(PERIOD);
  rs = avgGain / avgLoss;
  
  if (avgLoss == 0.0){
    rsi = 100.0;
  } else {
    rsi = 100.0 - (100.0 / (1.0 + rs));
  }


  if (rsi < 30.0) {                 # buy signal
    if (stopped) {
      stopped = false;
    } else {
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
        print(toString(currentOrderId) + " buy order (" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(t.price) + "  amount: "+ toString(AMOUNT));
    
        # emulating buy order filling
        transaction filledTran;
        filledTran.id = currentOrderId;
        filledTran.marker = currentOrderId;
        filledTran.price = t.price + t.price * randomf((1.0-minFillOrderPercentage), (1.0-maxFillOrderPercentage));
        filledTran.amount = AMOUNT;
        filledTran.fee = AMOUNT * t.price * FEE * 0.01;
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

        buyCount ++;
        setCurrentChartPosition("0");
        drawChartPointToSeries("Buy", t.tradeTime, t.price);
      }
    }
  }

  if (rsi > 70.0) {                 # sell signal
    if (stopped) {
      stopped = false;
    } else {
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
        print(toString(currentOrderId) + " sell order (" + timeToString(t.tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(t.price) + "  amount: "+ toString(AMOUNT));

        # emulating sell order filling
        transaction filledTran;
        filledTran.id = currentOrderId;
        filledTran.marker = currentOrderId;
        filledTran.price = t.price * randomf(minFillOrderPercentage, maxFillOrderPercentage);
        filledTran.amount = AMOUNT;
        filledTran.fee = AMOUNT * t.price * FEE * 0.01;
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
        
        sellCount ++;
        setCurrentChartPosition("0");
        drawChartPointToSeries("Sell", t.tradeTime, t.price);
      }
    }
  }
  
  setCurrentChartPosition("1");
  drawChartPointToSeries("RSI", t.tradeTime, rsi);
  
  lastPrice = t.price;
}

void backtest() {
  initCommonParameters();

  print("^^^^^^^^^^^^^^^^^ RSI Backtest ( EXCHANGE : " + EXCHANGESETTING + ", CURRENCY PAIR : " + SYMBOLSETTING + ") ^^^^^^^^^^^^^^^^^");
  print("");

  # Connection Checking
  integer conTestStartTime = getCurrentTime() - 3600000000;
  integer conTestEndTime = getCurrentTime();
  transaction conTestTrans[] = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, conTestStartTime, conTestEndTime);
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
  transaction transForTest[] = getPubTrades(EXCHANGESETTING, SYMBOLSETTING, testStartTime, testEndTime);

  integer resolution = interpretResol(RESOL);

  bar barData[] = getTimeBars(EXCHANGESETTING, SYMBOLSETTING, testStartTime, PERIOD, resolution * 60 * 1000 * 1000);

  for (integer i=1; i < sizeof(barData); i++) {
    priceChange = barData[i].closePrice - barData[i-1].closePrice;
    if (priceChange > 0.0) {
        gain += priceChange;
    }
    if (priceChange < 0.0) {
        loss += fabs(priceChange);
    }
    print("close price: " + toString(barData[i].closePrice) + " gain: " + toString(gain) + " loss: " + toString(loss));
  }
  avgGain = gain / toFloat(PERIOD);
  avgLoss = loss / toFloat(PERIOD);
  lastPrice = barData[sizeof(barData)-1].closePrice;
  rs = avgGain / avgLoss;
  if (avgLoss == 0.0) {
    rsi = 100.0;
  } else {
    rsi = 100.0 - (100.0 / (1.0 + rs));
  }

  print("--------- init result -------");
  print("close price: " + toString(lastPrice) + " gain: " + toString(gain) + " loss: " + toString(loss) + " avgGain: " + toString(avgGain) + " avgLoss: " + toString(avgLoss) + " rs: " + toString(rs) + "  rsi: " + toString(rsi));

  delete barData;  

  clearCharts();

  setChartBarCount(10);
  setChartBarWidth(24 * 60 * 60 * 1000000);                                # 1 day 
  setChartTime(transForTest[0].tradeTime +  777600000000); # 10min * 9  

  
  setCurrentSeriesName("Sell");
  configureScatter(true, "red", "red", 7.0);
  setCurrentSeriesName("Buy");
  configureScatter(true, "#7dfd63", "#187206", 7.0,);

  setCurrentChartPosition("1");
  setChartDataTitle("RSI - " + toString(14));
  setChartYRange(0.0, 100.0);
  
  setCurrentSeriesName("RSI");
  configureLine(true, "purple", 2.0);
  setCurrentSeriesName("30");
  configureLine(true, "green", 2.0);
  setCurrentSeriesName("70");
  configureLine(true, "pink", 2.0);


  float minAskOrderPrice = getOrderBookAsk(EXCHANGESETTING, SYMBOLSETTING);
  float maxBidOrderPrice = getOrderBookBid(EXCHANGESETTING, SYMBOLSETTING);

  order askOrders[] = getOrderBookByRangeAsks(EXCHANGESETTING, SYMBOLSETTING, 0.0, 1.0);
  order bidOrders[] = getOrderBookByRangeBids(EXCHANGESETTING, SYMBOLSETTING, 0.0, 1.0);


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

  integer cnt = sizeof(transForTest);
  integer step = resolution * 2;
  integer updateTicker = 0;
  integer msleepFlag = 0;

  integer timestampToStartLast24Hours = currentTime - 86400000000;  # 86400000000 = 24 * 3600 * 1000 * 1000
  integer lastUpdatedTimestamp = transForTest[0].tradeTime;

  integer timecounter = 0;

  setCurrentChartPosition("1");
  drawChartPointToSeries("30", testStartTime, 30.0);
  drawChartPointToSeries("30", testEndTime, 30.0);
  drawChartPointToSeries("70", testStartTime, 70.0);
  drawChartPointToSeries("70", testEndTime, 70.0);

  setChartsPairBuffering(true);

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
          print(toString(currentOrderId) + " sell order (" + timeToString(transForTest[i].tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(transForTest[i].price) + "  amount: "+ toString(AMOUNT));
          t.id = currentOrderId;
          t.marker = currentOrderId;
          t.price = transForTest[i].price * randomf(minFillOrderPercentage, maxFillOrderPercentage);
          t.amount = AMOUNT;
          t.fee = AMOUNT*t.price*FEE * 0.01;
          t.tradeTime = transForTest[i].tradeTime;
          t.isAsk = false;
          onOwnOrderFilledTest(t);
          sellCount ++;
          setCurrentChartPosition("0");
          drawChartPointToSeries("Sell", transForTest[i].tradeTime, transForTest[i].price);
        } else { # buy order emulation
          print(toString(currentOrderId) + " buy order (" + timeToString(transForTest[i].tradeTime, "yyyy-MM-dd hh:mm:ss") + ") : " + "base price: " + toString(transForTest[i].price) + "  amount: "+ toString(AMOUNT));
          t.id = currentOrderId;
          t.marker = currentOrderId;
          t.price = transForTest[i].price + transForTest[i].price * randomf((1.0-minFillOrderPercentage), (1.0-maxFillOrderPercentage));
          t.amount = AMOUNT;
          t.fee = AMOUNT*t.price*FEE * 0.01;
          t.tradeTime = transForTest[i].tradeTime;
          t.isAsk = true;
          onOwnOrderFilledTest(t);
          buyCount ++;
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
  
  string tradeListTitle = "Trade\tTime";
  tradeListTitle = strinsert(tradeListTitle, strlength(tradeListTitle), "\t\t");
  tradeListTitle = strinsert(tradeListTitle, strlength(tradeListTitle), SYMBOLSETTING);
  tradeListTitle = strinsert(tradeListTitle, strlength(tradeListTitle), "\tMax");
  tradeListTitle = strinsert(tradeListTitle, strlength(tradeListTitle), getBaseCurrencyName(SYMBOLSETTING));
  tradeListTitle = strinsert(tradeListTitle, strlength(tradeListTitle), "\tProf");
  tradeListTitle = strinsert(tradeListTitle, strlength(tradeListTitle), getQuoteCurrencyName(SYMBOLSETTING));
  tradeListTitle = strinsert(tradeListTitle, strlength(tradeListTitle), "\tAcc\tDrawdown");

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
}

backtest();