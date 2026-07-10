# A320 Loadsheets via ACARS
# Moritz Beitelschmidt

# Copyright (c) 2026 Moritz Beitelschmidt


## TODO

# - Final Loadsheet (alles andere als trivial, da die gewichte nicht einfach nur neue summen sind sondern den verbrauch beeinflussen etc. Ließe sich aber trotzdem erstmal "einfach" berechnen)



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


var data = ["empty"];

var init = func() {

    edno += 1;
    var r = {planned:, actual:,};
    append(data, r);

    if (activate == 1) {           # Hier checken ob Loadsheets in den Settings aktiviert
            if (simbrief == 1) {       # Hier checken ob Simbrief plan vorhanden, vielleicht noch timestamp abfragen damit bei neuem call durch simbrief neu geplant wird

                # Values as taken from the (simbrief) flightplan
                    var p = {};             # Assemble planned data into temporary hash

                    p.flightID = (Simbrief.SimbriefParser.OFP.getNode("general/icao_airline").getValue() or "") ~ (Simbrief.SimbriefParser.OFP.getNode("general/flight_number").getValue() or "");
                    p.departureID = (Simbrief.SimbriefParser.OFP.getNode("origin/iata_code").getValue() or "NA");
                    p.destinationID = (Simbrief.SimbriefParser.OFP.getNode("destination/iata_code").getValue() or "NA");

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
                    p.tof = Simbrief.SimbriefParser.store1.getChild("plan_takeoff").getValue();           # Take off fuel
                    p.laf = Simbrief.SimbriefParser.store1.getChild("plan_landing").getValue();           # Landing fuel

                    # CG
                    p.cgZfw = Loadsheet.calculate.CG.zfw();
                    p.macZfw = sprintf("%4.1f", math.round(Loadsheet.calculate.CGinch2MAC(p.cgZfw, offset, maclength), 0.1));
                    p.macTow = (Loadsheet.calculate.CG.projected(p.tof) or "NA");
                    p.macLaw = (Loadsheet.calculate.CG.projected(p.laf) or "NA");

                    p.pax = Simbrief.SimbriefParser.store2.getChild("pax_count").getValue();
#                    p.pax = Simbrief.SimbriefParser.store2.getChild("pax_count_actual").getValue();
                    p.crewPilots = 5; # In Simbrief als <crew> hinterlegt, man muss zählen
                    p.crewTotal = 7;
                    # Cabin sections

                    p.paxWeight = (Simbrief.SimbriefParser.store2.getChild("pax_weight").getValue() or 79.379 ) * KG2LB;
                    p.paxFront = p.pax / 3; ### TODO mit Loadmanager abstimmen
                    p.paxMid = p.pax / 3;
                    p.paxRear = p.pax / 3 ;

                    data[-1].planned = p;       # Write into data.planned with edition number as index

                }

                    # Fetch flightplan
                    var fp = flightplan();

                    var a = {};

                    a.registration = getprop("/options/model-options/registration");
                    a.departureID = (fp.departure.id or "NA");                              # TODO fetch the IATA codes
                    a.destinationID = (fp.destination.id or "NA");

                    #a.zfw = getprop("/fdm/jsbsim/inertia/XXXX");
                    a.maxZfw = math.round((getprop("/limits/mass-and-balance/maximum-zero-fuel-mass-lbs") * LB2KG), 100);

                    a.tow = math.round(fmgc.FMGCInternal.tow * LB2KG * 1000);                                               ### TODO Need to think if it is ok to use FMGC Data for the loadsheet....
                    a.maxTow = math.round((getprop("/limits/mass-and-balance/maximum-takeoff-mass-lbs") * LB2KG), 100);

                    a.law = math.round(fmgc.FMGCInternal.lw * LB2KG * 1000);
                    a.maxLaw = math.round((getprop("/limits/mass-and-balance/maximum-landing-mass-lbs") * LB2KG), 100);

                    a.fuelInTanks = math.round(getprop("/fdm/jsbsim/propulsion/total-fuel-lbs") * LB2KG, 10);
                    a.tof = a.fuelInTanks - fmgc.FMGCInternal.taxiFuel * LB2KG * 1000;
                    a.tif = fmgc.FMGCInternal.tripFuel * LB2KG;


                    a.macZfw = nil;
                    a.macTow = nil;

                    # Cabin sections

                    a.paxWeight = (data[-1].planned.paxWeight or 79.379 * KG2LB) ;
                    a.paxFront = math.floor(getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[0]") / a.paxWeight);
                    a.paxMid = math.floor(getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[1]") / a.paxWeight);
                    a.paxRear = math.floor(getprop("/fdm/jsbsim/inertia/pointmass-weight-lbs[2]") / a.paxWeight);

                    a.paxTotal = a.paxFront + a.paxMid + a.paxRear;

                    data[-1].actual = a;         # Write into data.actual
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

            },
            projected: func (fuel) {                     ### MOCKUP!!!
                if (getprop("/load-manager") != nil) {
                    # askTheLoadManager
                    return cg;
                } else {
                    return nil;
                }

            }
    }


};


var construct = func(lsFinal) {

    var revision = nil;
    var prefix = nil;
    if (lsFinal != 0) {
        prefix = data.planned;
    } else {
        prefix = data.actual;
    }

### LOADSHEET LINES AS INDIVIDUAL FUNCTIONS

    # Header with loadsheet type designation
    var l_header = func(f) {
        var r = "- LOADSHEET ";
        if ( f != 1 ) {
            l_header ~= "PRELIM";
        }
        else {
            l_header ~= "FINAL";
        }
        return r;
    }

    # EDNO with increments


    var l_edno = "EDNO " ~ str(Loadsheet.edno);

    # Flight number, day of flight, day of ls generation
    var l_fdata = (
        fmgc.FMGCInternal.flightNum ~
        "/" ~
        (var day = str(getprop("sim/time/utc/day"))) ~
        " " ~ day ~                                    # TODO read generation time from simbrief instead
        monthNames[getprop("sim/time/utc/month")] ~
        right(str(getprop("sim/time/utc/year")), 2)
        );
    # DEP and ARR ID, registration, Crew on board
    var  l_deparr = (
        data.planned.departureID ~ " " ~ data.planned.destinationID ~
        "  " ~ (data.actual.registration or data.planned.registration) ~ "   " ~ data.planned.crewPilots ~ "/" ~ data.planned.crewTotal
    );
    # ZFW
    var l_zfw = (
        "ZFW " ~ data.planned.zfw ~ "  MAX " ~ data.planned.maxZfw );
        if (data.planned.limitingFactor == 1) {
            l_zfw ~= " L";
        };
    # TOF
    var l_tof = (
        "TOF " ~ data.planned.tof );
    # TOW
    var l_tow = (
        "TOW " ~ data.planned.tow ~ "  MAX " ~ data.planned.maxTow );
        if (data.planned.limitingFactor == 2) {
            l_tow ~= " L";
        };
    # TIF
    var l_tif = (
        "TIF " ~ data.planned.tif );
    # Landing weight & max landing weight
    var l_law = (
        "LAW " ~ data.planned.law ~ "  MAX " ~ data.planned.maxLaw );
        if (data.planned.limitingFactor == 3) {
            l_law ~= " L";
        };
    # Underload
    var l_undld = (
        "UNDLD " ~ data.planned.underload);
    # PAX/0/159 TTL 159
    var l_pax = (
        "PAX/" ~ data.planned.pax ~ " " ~ "TTL " ~ data.planned.pax);
#     # PAX in sections
#     raw ~= (
#         "A" ~ data.planned.paxFront ~ " B" ~ data.planned.paxMid ~ " C" ~ data.planned.paxRear ~ "\n");
    # MAC at ZFW
    var l_maczfw = (
        "MACZFW " ~ data.planned.macZfw);
    # MAC at TOW
    var l_mactow = (
        "MACTOW " ~ data.planned.macTow);
    # MAC at LAW
    var l_maclaw = (
        "MACLAW " ~ data.planned.macLaw);
    # Fuel in tanks
    var l_fuelInTanks = (
        "FUEL IN TANKS " ~ data.actual.fuelInTanks);

    var l_dots = ("........................");






    if (lsFinal == 0) {
        var resultVector = [l_header(0),
                            l_edno,
                            l_fdata,
                            l_deparr,
                            l_zfw,
                            l_tof,
                            l_tow,
                            l_tif,
                            l_law,
                            l_undld,
                            l_pax,
                            l_maczfw,
                            l_mactow,
                            l_maclaw,
                            l_fuelInTanks
                 ];
    } elsif (lsFinal == 1) {

    }
    ;

    ### Normalize the line width to accomodate MCDU window
    var lineStretch = func() {
        var output = "";
        foreach (var i; resultVector) {
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



    ### Layouts



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



