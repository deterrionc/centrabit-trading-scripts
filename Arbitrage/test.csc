script Test;

import IO;
import Math;
import Strings;
import Trades;
import Time;
import Charts;
import Files;
import Processes;

#############################################
# User settings
string  EXCHANGESETTING = "Centrabit";
string  SYMBOLSETTING   = "LTC/BTC";
integer SMALEN          = 20;                       # SMA period length
float   STDDEVSETTING   = 1.0;                      # Standard Deviation
string  RESOL           = "1m";                     # Bar resolution
float   AMOUNT          = 0.1;                      # The amount of buy or sell order at once
float   STOPLOSSAT      = 0.01;                     # Stoploss as fraction of price
boolean USETRAILINGSTOP = true;

print(EXCHANGESETTING);
print(SYMBOLSETTING);
print(SMALEN);
print(STDDEVSETTING);
print(RESOL);
print(AMOUNT);
print(STOPLOSSAT);
print(USETRAILINGSTOP);

if (strlength(getEnv("EXCHANGESETTING")) != 0) {
  EXCHANGESETTING = getEnv("EXCHANGESETTING");
}
if (strlength(getEnv("SYMBOLSETTING")) != 0) {
  SYMBOLSETTING = getEnv("SYMBOLSETTING");
}
if (strlength(getEnv("SMALEN")) != 0) {
  SMALEN = toInteger(getEnv("SMALEN"));
}
if (strlength(getEnv("STDDEVSETTING")) != 0) {
  STDDEVSETTING = toFloat(getEnv("STDDEVSETTING"));
}
if (strlength(getEnv("RESOL")) != 0) {
  RESOL = getEnv("RESOL");
}
if (strlength(getEnv("AMOUNT")) != 0) {
  AMOUNT = toFloat(getEnv("AMOUNT"));
}
if (strlength(getEnv("STOPLOSSAT")) != 0) {
  STOPLOSSAT = toFloat(getEnv("STOPLOSSAT"));
}
if (strlength(getEnv("USETRAILINGSTOP")) != 0) {
  USETRAILINGSTOP = toBoolean(getEnv("USETRAILINGSTOP"));
}

print("\n");
print(EXCHANGESETTING);
print(SYMBOLSETTING);
print(SMALEN);
print(STDDEVSETTING);
print(RESOL);
print(AMOUNT);
print(STOPLOSSAT);
print(USETRAILINGSTOP);

#############################################

event onPubOrderFilled(string exchange, transaction t) {
  print(exchange);
  print(t.amount);
  print(t.isAsk);
}

event onOwnOrderFilled(string exchange, transaction t) {
  print(exchange);
  print(t.amount);
  print(t.isAsk);
}

void main() {

}

main();

