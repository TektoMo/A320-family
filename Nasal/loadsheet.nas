# A3XX Loadsheets via ACARS
# Moritz Beitelschmidt

# Copyright (c) 2026 Moritz Beitelschmidt

var digitsPerLine = 15;

var lsFinal = 1;
var edno = 0;

var monthNames = {
    1: "JAN", 2: "FEB", 3: "MAR", 4: "APR", 5: "MAY", 6: "JUN",
    7: "JUL", 8: "AUG", 9: "SEP", 10: "OCT", 11: "NOV", 12: "DEC"
};

# Initialize Numerical Values as parsed from somewhere else


var test = "Hallo";

var flightPlan = {
    zfw: nil,
    tof: nil,
    fuelInTanks: nil,
    tow: nil,
    tif: nil,
    law: nil,

    macZfw: nil,
    macTow: nil,
    paxTotal: nil,

    # Cabin sections

    cabinFront: nil,
    cabinMid: nil,
    cabinRear: nil,


};

# Define all possible elements of a loadsheet and do the appropriate calculations

# var header = "- LOADSHEET ";
#     if ( finalEd != 1 ) {
#         header = header ~ "PRELIM";
#     }
#     else {
#         header = header ~ "FINAL";
#     }





# var message = (
#     "- LOADSHEET PRELIM      " ~
#     "EDNO 1                  " ~
#     "DLH5L/3 3APR25          " ~
#     "ZFW" ~ str(flightPlan.zfw)
# );

var construct = func(lsFinal) {
    # Header with loadsheet type designation
    var raw = "- LOADSHEET ";
        if ( lsFinal != 1 ) {
            raw = raw ~ "PRELIM\n";
        }
        else {
            raw = raw ~ "FINAL\n";
        }
    # EDNO with increments
    Loadsheet.edno = Loadsheet.edno + 1;
    raw = raw ~ "EDNO " ~ str(edno) ~ "\n";
    # Flight number, day of flight, day of LS generation TODO read gen time from simbrief
    raw = (
        raw ~ fmgc.FMGCInternal.flightNum ~
        "/" ~
        (var day = str(getprop("sim/time/utc/day"))) ~
        " " ~ day ~
        monthNames[getprop("sim/time/utc/month")] ~
        right(str(getprop("sim/time/utc/year")), 2) ~ "\n"
        );
    print(raw);

    var receivedTime = left(getprop("/sim/time/gmt-string"), 5);
        me.receivedTime = split(":", receivedTime)[0] ~ "." ~ split(":", receivedTime)[1] ~ "Z";
    var message = mcdu.ACARSMessage.new(me.receivedTime, raw);
    mcdu.ReceivedMessagesDatabase.addMessage(message);

}
