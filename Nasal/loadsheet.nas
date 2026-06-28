# A3XX Loadsheets via ACARS
# Moritz Beitelschmidt

# Copyright (c) 2026 Moritz Beitelschmidt

var digitsPerLine = 24;
var activate = 1;  # TODO als Setting in der GUI verfügbar machen
var simbrief = 1;  # TODO checken ob Simbrief gelaufen ist


var lsFinal = 0;
var edno = 0;

var offset = -3.62865;
var maclength = 4.1935;





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
        if (activate == 1) {           # Hier checken ob Loadsheets in den Settings aktiviert
            if (simbrief == 1) {       # Hier checken ob Simbrief plan vorhanden, vielleicht noch timestamp abfragen damit bei neuem call durch simbrief neu geplant wird

                # Values as taken from the (simbrief) flightplan
                    var p = {};             # Assemble planned data into temporary hash

                    p.flightID = (Simbrief.SimbriefParser.OFP.getNode("general/icao_airline").getValue() or "") ~ (Simbrief.SimbriefParser.OFP.getNode("general/flight_number").getValue() or "");
                    p.departureIATA = (Simbrief.SimbriefParser.OFP.getNode("origin/iata_code").getValue() or "NA");
                    p.destinationIATA = (Simbrief.SimbriefParser.OFP.getNode("destination/iata_code").getValue() or "NA");

                    p.registration = (Simbrief.SimbriefParser.OFP.getNode("aircraft/reg").getValue() or "NA");

                    ### TIMES
                    p.fPlanTime = [[1,1,1970],[00,00]];
                    p.flightStartTime = [[1,1,1970],[00,00]];
                    ### WEIGHTS
                    p.zfw = Simbrief.SimbriefParser.store2.getChild("est_zfw").getValue();
                    p.maxZfw = Simbrief.SimbriefParser.store2.getChild("max_zfw").getValue();

                    p.tow = Simbrief.SimbriefParser.store2.getChild("est_tow").getValue();
                    p.maxTow = Simbrief.SimbriefParser.store2.getChild("max_tow_struct").getValue();

                    p.law = Simbrief.SimbriefParser.store2.getChild("est_ldw").getValue();
                    p.maxLaw = Simbrief.SimbriefParser.store2.getChild("max_ldw").getValue();

                    p.diffMaxWeights = [ ( p.maxZfw - p.zfw ), ( p.maxTow - p.tow ), ( p.maxLaw - p.law )];

                    var limits = Loadsheet.calculate.limitingFactor(p.diffMaxWeights);

                    p.limitingFactor = limits[0]; # 1 = ZFW, 2 = TOW, 3 = LAW
                    p.underload = limits[1];

                    ## FUEL
                    p.tif = Simbrief.SimbriefParser.store1.getChild("enroute_burn").getValue();           # Trip fuel
                    p.tof = Simbrief.SimbriefParser.store1.getChild("plan_takeoff").getValue();                        # Take off fuel

                    # CG
                    p.cgZfw = Loadsheet.calculate.CG.zfw();
                    p.macZfw = sprintf("%4.1f", math.round(Loadsheet.calculate.CGinch2MAC(p.cgZfw, offset, maclength), 0.1));
                    p.macTow = "NA";
                    p.macLaw = "NA";

                    p.pax = Simbrief.SimbriefParser.store2.getChild("pax_count").getValue();
#                    p.pax = Simbrief.SimbriefParser.store2.getChild("pax_count_actual").getValue();
                    p.crewPilots = 5; # In Simbrief als <crew> hinterlegt, man muss zählen
                    p.crewTotal = 7;
                    # Cabin sections
                    p.paxFront = p.pax / 3; ### TODO mit Loadmanager abstimmen
                    p.paxMid = p.pax / 3;
                    p.paxRear = p.pax / 3 ;

                    data.planned = p;           # Write into data.planned

                }

                    data.actual.registration = getprop("/options/model-options/registration");

                    data.actual.zfw = nil;
                    data.actual.tof = nil;
                    data.actual.fuelInTanks = sprintf("%s", math.round(getprop("/fdm/jsbsim/propulsion/total-fuel-lbs") * LB2KG, 10));
                    data.actual.tow = nil;
                    data.actual.tif = nil;
                    data.actual.law = nil;

                    data.actual.macZfw = nil;
                    data.actual.macTow = nil;
                    data.actual.paxTotal = nil;

                    # Cabin sections

                    data.actual.paxFront = nil;
                    data.actual.paxMid = nil;
                    data.actual.paxRear = nil;

        } else {
        print("Loadsheets deactivated");
        }
};

var calculate = {

    limitingFactor: func(diffs) {
        var minVal = diffs[0];
        var i = 1;
        var factorIndex = 1;
        foreach (var n; diffs) {
            if (n < minVal) {
                minVal = n;
                factorIndex = i;
            }
            i += 1;
        }
#         p.underload = minVal;
#         p.limitingFactor = factorIndex ;

        var res = [factorIndex, minVal];
        return res;
    },

    CGinch2MAC: func (cg, offset, maclength) {
        var cg = cg;
        var cgM = cg * IN2M;
        var mac = (( cgM - offset ) / maclength ) * 100;
        return mac;
    },

    CG: {

        zfw: func () {
            var numerator = (
            (getprop("/fdm/jsbsim/inertia/empty-weight-lbs") * getprop("/fdm/jsbsim/inertia/empty-weight-x-in"))
            + (getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[0]") * getprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[0]"))
            + (getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[1]") * getprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[1]"))
            + (getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[2]") * getprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[2]"))
            + (getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[3]") * getprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[3]"))
            + (getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[4]") * getprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[4]"))
            + (getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[5]") * getprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[5]"))
            );

            var denominator = (
                getprop("/fdm/jsbsim/inertia/empty-weight-lbs")
                + getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[0]")
                + getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[1]")
                + getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[2]")
                + getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[3]")
                + getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[4]")
                + getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[5]")
                );

            var cg = numerator/denominator;


            return cg;

            },
        current: func () {
                var numerator = (
                (getprop("/fdm/jsbsim/inertia/empty-weight-lbs") * getprop("/fdm/jsbsim/inertia/empty-weight-x-in"))
                + (getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[0]") * getprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[0]"))
                + (getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[1]") * getprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[1]"))
                + (getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[2]") * getprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[2]"))
                + (getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[3]") * getprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[3]"))
                + (getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[4]") * getprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[4]"))
                + (getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[5]") * getprop("/fdm/jsbsim/inertia/pointmass-location-X-inches[5]"))

                + (getprop("/fdm/jsbsim/propulsion/tank/contents-lbs") * getprop("/fdm/jsbsim/propulsion/tank/x-position"))
                + (getprop("/fdm/jsbsim/propulsion/tank[1]/contents-lbs") * getprop("/fdm/jsbsim/propulsion/tank[1]/x-position"))
                + (getprop("/fdm/jsbsim/propulsion/tank[2]/contents-lbs") * getprop("/fdm/jsbsim/propulsion/tank[2]/x-position"))
                + (getprop("/fdm/jsbsim/propulsion/tank[3]/contents-lbs") * getprop("/fdm/jsbsim/propulsion/tank[3]/x-position"))
                + (getprop("/fdm/jsbsim/propulsion/tank[4]/contents-lbs") * getprop("/fdm/jsbsim/propulsion/tank[4]/x-position"))
                + (getprop("/fdm/jsbsim/propulsion/tank[5]/contents-lbs") * getprop("/fdm/jsbsim/propulsion/tank[5]/x-position"))
                + (getprop("/fdm/jsbsim/propulsion/tank[6]/contents-lbs") * getprop("/fdm/jsbsim/propulsion/tank[6]/x-position"))
                + (getprop("/fdm/jsbsim/propulsion/tank[7]/contents-lbs") * getprop("/fdm/jsbsim/propulsion/tank[7]/x-position"))
                );

                var denominator = (
                getprop("/fdm/jsbsim/inertia/empty-weight-lbs")
                + getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[0]")
                + getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[1]")
                + getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[2]")
                + getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[3]")
                + getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[4]")
                + getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[5]")

                + getprop("/fdm/jsbsim/propulsion/tank/contents-lbs")
                + getprop("/fdm/jsbsim/propulsion/tank[1]/contents-lbs")
                + getprop("/fdm/jsbsim/propulsion/tank[2]/contents-lbs")
                + getprop("/fdm/jsbsim/propulsion/tank[3]/contents-lbs")
                + getprop("/fdm/jsbsim/propulsion/tank[4]/contents-lbs")
                + getprop("/fdm/jsbsim/propulsion/tank[5]/contents-lbs")
                + getprop("/fdm/jsbsim/propulsion/tank[6]/contents-lbs")
                + getprop("/fdm/jsbsim/propulsion/tank[7]/contents-lbs")
                );



            var cg = numerator/denominator;
            print(cg ~ " inches CG GROSSWEIGHT");
            print(Loadsheet.data.planned = CGinch2MAC(cg, offset, maclength));

            return cg;
                #
                #     Tank 0-8
                #     /fdm/jsbsim/propulsion/Tank  /contents-lbs
                #                                     /x-position
                #

            }
    },
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
        "  " ~ (data.actual.registration or data.planned.registration) ~ "   " ~ str(data.planned.crewPilots) ~ "/" ~ str(data.planned.crewTotal) ~ "\n"
    );
    # ZFW
    raw ~= (
        "ZFW " ~ data.planned.zfw ~ "  MAX " ~ data.planned.maxZfw );
        if (data.planned.limitingFactor == 1) {
            raw ~= " L";
        } raw ~= " \n";
    # TOF
    raw ~= (
        "TOF " ~ data.planned.tof ~ "\n" );
    # TOW
    raw ~= (
        "TOW " ~ data.planned.tow ~ "  MAX " ~ data.planned.maxTow );
        if (data.planned.limitingFactor == 2) {
            raw ~= " L";
        } raw ~= " \n";
    # TIF
    raw ~= (
        "TIF " ~ data.planned.tif ~ "\n" );
    # Landing weight & max landing weight
    raw ~= (
        "LAW " ~ data.planned.law ~ "  MAX " ~ data.planned.maxLaw );
    if (data.planned.limitingFactor == 3) {
        raw ~= " L";
    } raw ~= " \n";
    # Underload
    raw ~= (
        "UNDLD " ~ data.planned.underload ~ "\n");
    # PAX/0/159 TTL 159
    raw ~= (
        "PAX/" ~ data.planned.pax ~ " " ~ "TTL " ~ data.planned.pax ~ "\n");
#     # PAX in sections
#     raw ~= (
#         "A" ~ data.planned.paxFront ~ " B" ~ data.planned.paxMid ~ " C" ~ data.planned.paxRear ~ "\n");
    # MAC at ZFW
    raw ~= (
        "MACZFW " ~ data.planned.macZfw ~ "\n");
    # MAC at TOW
    raw ~= (
        "MACTOW " ~ data.planned.macTow ~ "\n");
    # MAC at LAW
    raw ~= (
        "MACLAW " ~ data.planned.macLaw ~ "\n");
    # Fuel in tanks
    raw ~= (
        "FUEL IN TANKS " ~ data.actual.fuelInTanks ~ "\n");

    data.planned.output = raw;                                  ### If you want a correctly formatted string with newlines, here is your chance to get it.

    ### Normalize the line width to accomodate MCDU window
    var lineStretch = func() {
        var output = "";
        var sep = split("\n", raw);
        foreach (var i; sep) {
            output ~= sprintf("%-" ~ digitsPerLine ~ "s", i);

#             var len = digitsPerLine - size(sep[i]);
#             while (len > 0) {
#                 sep[i] ~= " ";
#                 len -= 1;
#             }
#             output ~= sep[i];
        }
        return output;
    }

    var finalString = lineStretch();
    print(finalString);

    sendMessage(finalString);

    ### QUICK AND VERY DIRTY MESSAGE SPREADER
    if ( size(finalString) > 216) {
        sendMessage(substr(finalString, 216));
        if ( size(finalString) > 432) {
            sendMessage(substr(finalString, 432));
        }

    }

};

# Send Output to ACARS
var sendMessage = func(s) {
    var string = s;
    var receivedTime = left(getprop("/sim/time/gmt-string"), 5);
        receivedTime = split(":", receivedTime)[0] ~ "." ~ split(":", receivedTime)[1] ~ "Z";
    var message = mcdu.ACARSMessage.new(receivedTime, string);
        mcdu.ReceivedMessagesDatabase.addMessage(message);

    };



