# A3XX Loadsheets via ACARS
# Moritz Beitelschmidt

# Copyright (c) 2026 Moritz Beitelschmidt

var digitsPerLine = 15;
var activate = 1;  # TODO als Setting in der GUI verfügbar machen
var simbrief = 1;  # TODO checken ob Simbrief gelaufen ist


var lsFinal = 1;
var edno = 0;

var monthNames = {
    1: "JAN", 2: "FEB", 3: "MAR", 4: "APR", 5: "MAY", 6: "JUN",
    7: "JUL", 8: "AUG", 9: "SEP", 10: "OCT", 11: "NOV", 12: "DEC"
};

# Initialize Numerical Values as parsed from somewhere else or the sim


var data = {
    planned: {},
    actual: {},
};
var init = func() {
        if (activate == 1) {                         # Hier checken ob Loadsheets in den Settings aktiviert
            if (simbrief == 1) {       # Hier checken ob Simbrief plan vorhanden, vielleicht noch timestamp abfragen damit bei neuem call durch simbrief neu geplant wird
                # Values as taken from the (simbrief) flightplan
                    # Flight metadata

                    data.planned.flightID = (Simbrief.SimbriefParser.OFP.getNode("general/icao_airline").getValue() or "") ~ (Simbrief.SimbriefParser.OFP.getNode("general/flight_number").getValue() or "");
                    data.planned.departureIATA = (Simbrief.SimbriefParser.OFP.getNode("origin/iata_code").getValue() or "NA");
                    data.planned.destinationIATA = (Simbrief.SimbriefParser.OFP.getNode("destination/iata_code").getValue() or "NA");

                    ### TIMES
                    data.planned.fPlanTime = [[1,1,1970],[00,00]];
                    data.planned.flightStartTime = [[1,1,1970],[00,00]];
                    ### WEIGHTS
                    data.planned.zfw = Simbrief.SimbriefParser.store2.getChild("est_zfw").getValue();
                    data.planned.maxZfw = Simbrief.SimbriefParser.store2.getChild("max_zfw").getValue();

                    data.planned.tow = Simbrief.SimbriefParser.store2.getChild("est_tow").getValue();
                    data.planned.maxTow = Simbrief.SimbriefParser.store2.getChild("max_tow").getValue();

                    data.planned.law = Simbrief.SimbriefParser.store2.getChild("est_ldw").getValue();
                    data.planned.maxLaw = Simbrief.SimbriefParser.store2.getChild("max_ldw").getValue();

                    data.planned.diffMaxWeights = [ ( data.planned.maxZfw - data.planned.zfw ), ( data.planned.maxTow - data.planned.tow ), ( data.planned.maxLaw - data.planned.law )];


                    var limitingFactorCalc = func() {
                        var minVal = data.planned.diffMaxWeights[0];
                        var i = 1;
                        var factorIndex = 1;
                        foreach (var n; data.planned.diffMaxWeights) {
                            if (n < minVal) {
                                minVal = n;
                                factorIndex = i;

                            }
                            i += 1;
                        }
                        data.planned.underload = minVal;
                        data.planned.limitingFactor = factorIndex ;             # 1 = ZFW, 2 = TOW, 3 = LAW

                        # Append L behind the respective limiting factor string
                        if (factorIndex == 1) {
                            data.planned.maxZfw ~= " L";
                        } elsif (factorIndex == 2 ) {
                            data.planned.maxTow ~= " L";
                        } elsif (factorIndex == 3 ) {
                            data.planned.maxLaw ~= " L";
                        }


                    };
                    limitingFactorCalc();

                    ## FUEL
                    data.planned.tif = Simbrief.SimbriefParser.store1.getChild("enroute_burn").getValue();           # Trip fuel
                    data.planned.tof = Simbrief.SimbriefParser.store1.getChild("plan_takeoff").getValue();                        # Take off fuel


                    data.planned.fuelInTanks = nil;

                    data.planned.macZfw = nil;
                    data.planned.macTow = nil;

                    data.planned.pax = Simbrief.SimbriefParser.store2.getChild("pax_count").getValue();
#                    data.planned.pax = Simbrief.SimbriefParser.store2.getChild("pax_count_actual").getValue();
                    data.planned.crewPilots = 5; # In Simbrief als <crew> hinterlegt, man muss zählen
                    data.planned.crewTotal = 7;
                    # Cabin sections



                    data.planned.cabinFront = nil;
                    data.planned.cabinMid = nil;
                    data.planned.cabinRear = nil;


                }

                    data.actual.registration = "G-ABCD";

                    data.actual.zfw = nil;
                    data.actual.tof = nil;
                    data.actual.fuelInTanks = nil;
                    data.actual.tow = nil;
                    data.actual.tif = nil;
                    data.actual.law = nil;

                    data.actual.macZfw = nil;
                    data.actual.macTow = nil;
                    data.actual.paxTotal = nil;

                    # Cabin sections

                    data.actual.cabinFront = nil;
                    data.actual.cabinMid = nil;
                    data.actual.cabinRear = nil;

        }
        print("Loadsheets deactivated");
};


var construct = func(lsFinal, planned, actual) {
    # Header with loadsheet type designation
    var raw = "- LOADSHEET ";
        if ( lsFinal != 1 ) {
            raw ~= "PRELIM\n";
        }
        else {
            raw ~= "FINAL\n";
        }

    # EDNO with increments
    Loadsheet.edno = Loadsheet.edno + 1;
    raw ~= "EDNO " ~ str(Loadsheet.edno) ~ "\n";

    # Flight number, day of flight, day of ls generation
    raw ~= (
        fmgc.FMGCInternal.flightNum ~
        "/" ~
        (var day = str(getprop("sim/time/utc/day"))) ~
        " " ~ day ~                                    # TODO read generation time from simbrief instead
        monthNames[getprop("sim/time/utc/month")] ~
        right(str(getprop("sim/time/utc/year")), 2) ~ "\n"
        );
    # DEP and ARR IATA, registration, Crew on board
    raw ~= (
        data.planned.departureIATA ~ " " ~ data.planned.destinationIATA ~
        "  " ~ data.actual.registration ~ "   " ~ str(data.planned.crewPilots) ~ "/" ~ str(data.planned.crewTotal) ~ "\n"
    );
    # ZFW
    raw ~= (
        "ZFW " ~ data.planned.zfw ~ "   " ~ "MAX " ~ data.planned.maxZfw ~ "   \n" );
    # TOF
    raw ~= (
        "TOF " ~ data.planned.tof ~ "\n" );
    # TOW
    raw ~= (
        "TOW " ~ data.planned.tow ~ "   " ~ "MAX " ~ data.planned.maxTow ~ "\n" );
    # TIF
    raw ~= (
        "TIF " ~ data.planned.tif ~ "\n" );
    # Landing weight & max landing weight
    raw ~= (
        "LAW " ~ data.planned.law ~ " " ~ "MAX " ~ data.planned.maxLaw ~ "\n");
    # Underload
    raw ~= (
        "UNDLD " ~ data.planned.underload ~ "\n");
    # PAX/0/159 TTL 159
    raw ~= (
        "PAX/" ~ data.planned.pax ~ " " ~ "TTL " ~ data.planned.pax ~ "\n");

    print(raw);
    data.planned.output = raw;


# Send Output to ACARS
    var receivedTime = left(getprop("/sim/time/gmt-string"), 5);
        me.receivedTime = split(":", receivedTime)[0] ~ "." ~ split(":", receivedTime)[1] ~ "Z";
    var message = mcdu.ACARSMessage.new(me.receivedTime, raw);
    mcdu.ReceivedMessagesDatabase.addMessage(message);

}
