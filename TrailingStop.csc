boolean stopLossTick(float price) {
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

# Bollinger Bands
void onPubOrderFilledTest(transaction t) {
  currentTran = t;
  drawChartPointToSeries("Middle", t.tradeTime, sma);
  drawChartPointToSeries("Upper", t.tradeTime, upperBand);
  drawChartPointToSeries("Lower", t.tradeTime, lowerBand);
  lastPrice = t.price;

  if (stopLossFlag) {
    currentOrderId++;

    if (position == "long") {     # Bought -> Sell
      printOrderLogs(currentOrderId, "Sell", t.tradeTime, t.price, AMOUNT, "  (StopLoss order)");

      buyStopped = true;
      # Emulate Sell Order
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

      sellStopped = true;
      # Emulate Buy Order
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
}