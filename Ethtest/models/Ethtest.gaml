/**PROJECT INFO
    *Name: Ethtest
    *Connection tester for python server
    *Author: Enrique Ortiz Macias, Liliana Durán Polanco
    *Tags:
*/
//

/*coordenadas en el escenario:
    {  0.0 ,   0.0}; //left top
    {  0.0 , 100.0}; //left bottom
    {100.0 ,   0.0}; //right top
    {100.0 , 100.0}; //right bottom
*/
//

model Ethtest

global {

    ///////////////////////////////////////////////////////////////////////////
    //--GLOBAL VARIABLES------------------------------------------------------

        //acerca del cyclestoloop
        //la simulación debe correr en la velocidad más lenta: 1 ciclo x segundo
        //el refresh constante tarda 2 segundos entre request y response
        //o sea que necesitamos 2 segundos nomás para hablar con ETH, y más tiempo para procesar la respuesta
        //el refresh será cada 10 segundos, para dar tiempo de sobra para otros requests
        //porque además del refresh están los requests de uploadReadings y el de evalReadings
        //que pueden ser hasta 13 x ciclo...
        //o sea que en teoría un ciclo puede contener hasta 14 llamadas a ETH, eso son 28 segundos
        //mas el tiempo de procesamiento de cada response...
        //demonios...

        string prefix_client <- "Client_"; //todos los clientes tendrán el prefijo "Client_"
        int simulation_id    <- 0;
        int cyclestoloop     <- 10; //ponlo en la velocidad más lenta!
        int counterdown      <- cyclestoloop;
        int refreshcounter   <- 0;
        int devicelimit      <- 14;
        int cn_limit         <- 2;
        int satellitelimit   <- 8;
        int th_low_bound     <- 1;
        int th_high_bound    <- 10;
        int cns_will_log     <- 0;
        int cns_will_eval    <- 0;
        int tcpclients       <- 10;
        bool got_response    <- true; //por default se pueden lanzar requests a ETH
        bool showcounter     <- false;

		list<string> summary <- [];

        list<TCP_Client> tcps     <- [];
        list<TCP_Client> freetcps <- [];

        map<string,list<int>> devices <- [
            "compute_nodes" :: list<int>([]),
            "sensors"       :: list<int>([]),
            "actuators"     :: list<int>([])
        ];

        //----------------------------------------------------------------------------------
        //variables para gráficos:

        float satellite_radius_min <- 1.0;
        float satellite_radius_max <- 10.0;
        float satellite_proximity  <- 5.0;

        int   spotlights           <- 3; //ponle 2 o 3 para debuggear...
        float spotlight_radius     <- 20.0;
        float spotlight_speed      <- 3.0;

        file actuator_disabled     <- image_file("../includes/data/bulb_disabled.png");
        file actuator_off          <- image_file("../includes/data/bulb_off.png");
        file actuator_on           <- image_file("../includes/data/bulb_on.png");
        file compute_node          <- image_file("../includes/data/compute_node.png");
        file compute_node_disabled <- image_file("../includes/data/compute_node_disabled.png");
        file sensor_disabled       <- image_file("../includes/data/sensor_disabled.jpg");
        file sensor_off            <- image_file("../includes/data/sensor_off.jpg");
        file sensor_on             <- image_file("../includes/data/sensor_on.jpg");

        float icon_size <- 5.0;

		map<point,bool> places <- [
			{20,20} :: false,
			{50,20} :: false,
			{80,20} :: false,
			{20,50} :: false,
			{50,50} :: false,
			{80,50} :: false,
			{20,80} :: false,
			{50,80} :: false,
			{80,80} :: false
		];
    ////

    ///////////////////////////////////////////////////////////////////////////
    //--DEVICE ATTRIBUTE MAPPINGS---------------------------------------------

        map<int,string> ckeytoname <- [
            0   :: "DEFAULT",
            1   :: "SENSOR",
            2   :: "ACTUATOR",
            3   :: "COMPUTE_NODE",
            10  :: "LOW",
            11  :: "HIGH",
            110 :: "AMOUNT_SENSORS",
            120 :: "AMOUNT_ACTUATORS",
            130 :: "THRESHOLD",
            210 :: "LAST_READING",
            310 :: "ACT_COMMAND",
            410 :: "PARENT",
            510 :: "ID",
            520 :: "TYPE",
            530 :: "PUBLIC_KEY",
            540 :: "PERMISSION",
            550 :: "ON_OFF_STATUS"
        ];

        map<string,int> ckeytonumber <- [
            "DEFAULT"          :: 0,
            "SENSOR"           :: 1,
            "ACTUATOR"         :: 2,
            "COMPUTE_NODE"     :: 3,
            "LOW"              :: 10,
            "HIGH"             :: 11,
            "AMOUNT_SENSORS"   :: 110,
            "AMOUNT_ACTUATORS" :: 120,
            "THRESHOLD"        :: 130,
            "LAST_READING"     :: 210,
            "ACT_COMMAND"      :: 310,
            "PARENT"           :: 410,
            "ID"               :: 510,
            "TYPE"             :: 520,
            "PUBLIC_KEY"       :: 530,
            "PERMISSION"       :: 540,
            "ON_OFF_STATUS"    :: 550
        ];
    ////

    ///////////////////////////////////////////////////////////////////////////
    //--VARIABLES FOR MANUAL INPUTS AND ETH FUNCTIONS-------------------------

        string createDevice_tipo              <- "";
        string replaceDevice_sa_id            <- "";
        string destroySatellite_sa_id         <- "";
        string destroyComputeNode_cn_id       <- "";
        string unlinkSubDevice_sa_id          <- "";
        string linkDeviceToComputeNode_sa_id  <- "";
        string linkDeviceToComputeNode_new_cn <- "";
        string applyDefaultConfig_device_id   <- "";
        string applyDefaultConfig_tipo        <- "";
        string setPublicKey_device_id         <- "";
        string setPublicKey_config_value      <- "";
        string setThreshold_cn_id             <- "";
        string setThreshold_config_value      <- "";
        string grantPerms_device_id           <- "";
        string denyPerms_device_id            <- "";
        string turnOnDevice_device_id         <- "";
        string turnOffDevice_device_id        <- "";
    ////

    ///////////////////////////////////////////////////////////////////////////
    //--FUNCTIONS FOR RESPONSE HANDLING---------------------------------------

        //---------------------------------------------------------
        //funciones variadas...

        string getMachineTime {

            float totalmsec <- machine_time;              //todo el tiempo, expresado en milisegundos
            int msec <- (totalmsec mod 1000);             //sobrante: milisegundos que no alcanzan a formar 1 segundo (999 o menos)

            int totalsec <- int((totalmsec-msec) / 1000); //todo el tiempo que teníamos, expresado en segundos, menos los milisegundos que sobraron
            int sec <- (totalsec mod 60);                 //sobrante: segundos que no alcanzan a formar 1 minuto (59 o menos)

            int totalmin <- int((totalsec-sec) / 60);     //todo el tiempo que teníamos, expresado en minutos, menos los segundos que sobraron
            int min <- (totalmin mod 60);                 //sobrante: minutos que no alcanzan a formar 1 hora (59 o menos)

            int totalhour <- int((totalmin-min) / 60);    //todo el tiempo que teníamos, expresado en horas, menos los minutos que sobraron
            int hour <- (totalhour mod 24);               //sobrante: horas que no alcanzan a formar 1 día (23 o menos)

            int totalday <- int((totalhour-hour) / 24);   //todo el tiempo que teníamos, expresado en días, menos las horas que sobraron

            if(hour<5) {hour <- hour + 24;}

            return ""+zeroPadNumber((hour-5),2)+":"+zeroPadNumber(min,2)+":"+zeroPadNumber(sec,2)+"."+zeroPadNumber(msec,3);
        }
        //getMachineTime

        int deviceAmount {
            //para poder foldear
            return(length(ComputeNode) + length(Sensor) + length(Actuator));
        }
        //deviceAmount

        string zeroPadNumber(int num, int dpad) {

            string zpnum <- string(num);

            loop while:(length(zpnum)<dpad) {
                zpnum <- "0"+zpnum;
            }
            //loop

            return zpnum;
        }
        //zeroPadNumber

        string tabPadBinary(int bin) {
            if bin=ckeytonumber["HIGH"] {
                return ckeytoname[bin]+",\t";
            }else {
                return ckeytoname[bin]+",\t\t";
            }
            //if-else
        }
        //tabPadBinary

        string prettyPrintAttrs(map<string,int> attrmap) {

            string prettystr <- "[";

            int attr_iidd <- attrmap["ID"];
            int attr_type <- attrmap["TYPE"];
            int attr_pkey <- attrmap["PUBLIC_KEY"];
            int attr_perm <- attrmap["PERMISSION"];
            int attr_stat <- attrmap["ON_OFF_STATUS"];

            switch attrmap["TYPE"] {

                match ckeytonumber["SENSOR"] { //sensor

                    int attr_parn <- attrmap["PARENT"];
                    int attr_read <- attrmap["LAST_READING"];

                    prettystr <- prettystr + "ID:"            + zeroPadNumber(attr_iidd,2) + ",\t";
                    prettystr <- prettystr + "TYPE:"          + ckeytoname[attr_type] + ",\t\t";
                    prettystr <- prettystr + "PUBLIC_KEY:"    + zeroPadNumber(attr_pkey,4) + ",\t";
                    prettystr <- prettystr + "PERMISSION:"    + tabPadBinary(attr_perm);
                    prettystr <- prettystr + "ON_OFF_STATUS:" + ckeytoname[attr_stat] + ",\t\t";
                    prettystr <- prettystr + "LAST_READING:"  + zeroPadNumber(attr_read,2) + ",\t\t";
                    prettystr <- prettystr + "PARENT:"        + zeroPadNumber(attr_parn,2);
                    break;
                }
                match ckeytonumber["ACTUATOR"] { //actuator

                    int attr_parn <- attrmap["PARENT"];
                    int attr_comm <- attrmap["ACT_COMMAND"];

                    prettystr <- prettystr + "ID:"            + zeroPadNumber(attr_iidd,2) + ",\t";
                    prettystr <- prettystr + "TYPE:"          + ckeytoname[attr_type] + ",\t\t";
                    prettystr <- prettystr + "PUBLIC_KEY:"    + zeroPadNumber(attr_pkey,4) + ",\t";
                    prettystr <- prettystr + "PERMISSION:"    + tabPadBinary(attr_perm);
                    prettystr <- prettystr + "ON_OFF_STATUS:" + ckeytoname[attr_stat] + ",\t\t";
                    prettystr <- prettystr + "ACT_COMMAND:"   + ckeytoname[attr_comm] + ",\t\t";
                    prettystr <- prettystr + "PARENT:"        + zeroPadNumber(attr_parn,2);
                    break;
                }
                match ckeytonumber["COMPUTE_NODE"] { //computenode

                    int attr_nums <- attrmap["AMOUNT_SENSORS"];
                    int attr_numa <- attrmap["AMOUNT_ACTUATORS"];
                    int attr_thld <- attrmap["THRESHOLD"];

                    prettystr <- prettystr + "ID:"               + zeroPadNumber(attr_iidd,2) + ",\t";
                    prettystr <- prettystr + "TYPE:"             + ckeytoname[attr_type] + ",\t";
                    prettystr <- prettystr + "PUBLIC_KEY:"       + zeroPadNumber(attr_pkey,4) + ",\t";
                    prettystr <- prettystr + "PERMISSION:"       + tabPadBinary(attr_perm);
                    prettystr <- prettystr + "ON_OFF_STATUS:"    + ckeytoname[attr_stat] + ",\t\t";
                    prettystr <- prettystr + "THRESHOLD:"        + zeroPadNumber(attr_thld,2) + ",\t\t\t";
                    prettystr <- prettystr + "AMOUNT_SENSORS:"   + zeroPadNumber(attr_nums,2) + ",\t";
                    prettystr <- prettystr + "AMOUNT_ACTUATORS:" + zeroPadNumber(attr_numa,2);
                    break;
                }
                //match
            }
            //switch type

            prettystr <- prettystr + "]";
            return prettystr;
        }
        //prettyPrintAttrs

        string removeRemainder(string somestr) {
            //esto lo tengo que hacer porque GAMA pone caracteres no imprimibles a la derecha de lo que llega por UDP
            list<string> both_halves;
            both_halves <- (somestr split_with("!"));
            return both_halves[0];
        }
        //removeRemainder

        action showSummary {
            write "\n|||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||||";
            write "SYSTEM STATE AT CYCLE "+cycle+" AFTER "+refreshcounter+" REFRESH CALLS:";
            write "Amount of Compute Nodes: -- "+length(ComputeNode);
            write "Amount of Sensors: -------- "+length(Sensor);
            write "Amount of Actuators: ------ "+length(Actuator);
            summary <- [];
            ask ComputeNode {write self.showUp();}
            ask Sensor      {write self.showUp();}
            ask Actuator    {write self.showUp();}
            //write ""; //descomentar si necesito una línea en blanco
        }
        //reflex showSummary

		action spawnSummaries {

			ask SummaryContainer {do die;}

			float curr_y    <- 2.0;
			float interline <- 1.5;

			create SummaryContainer number:1 with:[location::{1, curr_y}, summarystr::"SUMMARY:"];
			loop ss over:summary {
				curr_y <- curr_y + interline;
				create SummaryContainer number:1 with:[location::{1, curr_y}, summarystr::ss];
			}
			//loop
		}
		//spawnSummaries

        //---------------------------------------------------------
        //funciones para verificar dispositivos...

        bool computeNodeExists(int id_to_find) {
            list<ComputeNode> foundthis <- ComputeNode where(each.id=id_to_find);
            if empty(foundthis) {return false;}
            return true;
        }
        //computeNodeExists

        bool sensorExists(int id_to_find) {
            list<Sensor> foundthis <- Sensor where(each.id=id_to_find);
            if empty(foundthis) {return false;}
            return true;
        }
        //sensorExists

        bool actuatorExists(int id_to_find) {
            list<Actuator> foundthis <- Actuator where(each.id=id_to_find);
            if empty(foundthis) {return false;}
            return true;
        }
        //actuatorExists

        string getDeviceType(int devid) {

            int dev_tipo1 <- ckeytonumber["DEFAULT"];
            int dev_tipo2 <- ckeytonumber["DEFAULT"];
            int dev_tipo3 <- ckeytonumber["DEFAULT"];

            ask Sensor      where(each.id=devid) {dev_tipo1 <- self.attrs["TYPE"];}
            ask Actuator    where(each.id=devid) {dev_tipo2 <- self.attrs["TYPE"];}
            ask ComputeNode where(each.id=devid) {dev_tipo3 <- self.attrs["TYPE"];}

            return string(max([dev_tipo1, dev_tipo2, dev_tipo3]));
        }
        //getDeviceType

        //---------------------------------------------------------
        //funciones para hacer llamadas a ETH...

        action pickTCPAndSend(string msg_str, string wait_str) {
            freetcps <- (tcps where(each.free));
            ask one_of(freetcps) {do sendToETH(msg_str, wait_str);}
            return;
        }
        //pickTCPAndSend

        //---------------------------------------------------------
        //funciones para actualizar el estado del sistema

        action createAgent(int id_to_assign, string type_to_assign) {

            switch type_to_assign {

                match_one ["3","COMPUTE_NODE"] {
                    create ComputeNode number:1 with:[id::id_to_assign, type::"COMPUTE_NODE"];
                    break;
                }
                match_one ["1","SENSOR"] {
                    create Sensor number:1 with:[id::id_to_assign, type::"SENSOR"];
                    break;
                }
                match_one ["2","ACTUATOR"] {
                    create Actuator number:1 with:[id::id_to_assign, type::"ACTUATOR"];
                    break;
                }
                //match
            }
            //switch type_to_assign
        }
        //createAgent

        //Según la lista de dispositivos sacada del ledger, crear y/o destruir los dispositivos de GAMA
        action refreshDevices(string dl) {

            //Armar map de devices que deben existir según el ledger

            devices["compute_nodes"] <- [];
            devices["sensors"]       <- [];
            devices["actuators"]     <- [];

            //write "dl at refreshDevices is: ["+dl+"]"; //descomentar para debuggear

            if dl!="" {

                //dl viene en la forma:
                //26:CN,12:S,14:S,16:A,69:A,36:CN,49:S,45:S,78:A,76:A,86:S,87:S,88:A

                list<string> device_arr <- dl split_with(",");
                list<string> device_pair;

                loop d over:device_arr {

                    device_pair <- d split_with(":");

                    switch device_pair[1] {
                        match "S" {
                            add int(device_pair[0]) to:devices["sensors"]; //sensor
                            break;
                        }
                        match "A" {
                            add int(device_pair[0]) to:devices["actuators"]; //actuator
                            break;
                        }
                        match "CN" {
                            add int(device_pair[0]) to:devices["compute_nodes"]; //compute node
                            break;
                        }
                        //match
                    }
                    //switch
                }
                //loop
            }
            //if dl!=""

            //Device que exista en el ledger pero no en GAMA, se crea.

            loop d over:devices["compute_nodes"] {
                if not(computeNodeExists(d)) {
                    do createAgent(d, "COMPUTE_NODE");
                }
                //if
            }
            //loop over compute_nodes

            loop d over:devices["sensors"] {
                if not(sensorExists(d)) {
                    do createAgent(d, "SENSOR");
                }
                //if
            }
            //loop over sensors

            loop d over:devices["actuators"] {
                if not(actuatorExists(d)) {
                    do createAgent(d, "ACTUATOR");
                }
                //if
            }
            //loop over actuators

            //Device que exista en GAMA pero no en el ledger, se elimina.

            ask Sensor where not(each.id in devices["sensors"]) {
            	do freeUpPlace();
            	do die;
            }
            //ask

            ask Actuator where not(each.id in devices["actuators"]) {
            	do freeUpPlace();
            	do die;
            }
            //ask
            
            ask ComputeNode where not(each.id in devices["compute_nodes"]) {
            	do freeUpPlace();
            	do die;
            }
            //ask

            //write "Device list refreshed.";
            return;
        }
        //refreshDevices

        //Según la info de un device sacada del ledger, actualizar los atributos de ese device
        action refreshAttributes(int device_id, string device_attr) {

            //device_attr viene en la forma:
            //sensor:       ID:49|TYPE:1|PUBLIC_KEY:378537|PERMISSION:11|ON_OFF_STATUS:11|PARENT:36|LAST_READING:0
            //actuator:     ID:69|TYPE:2|PUBLIC_KEY:985953|PERMISSION:11|ON_OFF_STATUS:11|PARENT:26|ACT_COMMAND:10
            //compute_node: ID:26|TYPE:3|PUBLIC_KEY:113634|PERMISSION:11|ON_OFF_STATUS:11|AMOUNT_SENSORS:2|AMOUNT_ACTUATORS:2|THRESHOLD:0

            list<string> attr_arr <- device_attr split_with("|");
            list<string> attr_pair;

            map<string,int> device_attributes <- [];

            loop a over:attr_arr {
                attr_pair <- a split_with(":");
                device_attributes[attr_pair[0]] <- int(attr_pair[1]);
            }
            //loop over attr_arr

            switch device_attributes["TYPE"] {

                match ckeytonumber["SENSOR"] {
                    ask Sensor where(each.id=device_id) {
                        self.attrs <- device_attributes;
                        do refreshParent;
                    }
                    //ask
                    break;
                }
                match ckeytonumber["ACTUATOR"] {
                    ask Actuator where(each.id=device_id) {
                        self.attrs <- device_attributes;
                        do refreshParent;
                    }
                    //ask
                    break;
                }
                match ckeytonumber["COMPUTE_NODE"] {
                    ask ComputeNode where(each.id=device_id) {
                        self.attrs <- device_attributes;
                    }
                    //ask
                    break;
                }
                //match
            }
            //switch

            //write "Device "+device_id+"'s attributes refreshed.";
            return;
        }
        //refreshAttributes

        //Según la lista de satélites de un CN sacada del ledger, actualizar las listas de satélites de ese CN
        action refreshSatellites(int computenode_id, string satellite_str) {

            //satellite_str viene en la forma:
            //"S:|A:"              //si no tiene satélites
            //"S:12,14,17|A:"      //si tiene sólo sensores
            //"S:|A:16,69"         //si tiene sólo actuadores
            //"S:12,14,17|A:16,69" //si tiene ambos satélites

            list<string> list_of_sensors_str   <- [];
            list<string> list_of_actuators_str <- [];

            list<int> new_child_sensors   <- [];
            list<int> new_child_actuators <- [];

            int s_num;
            int a_num;

            ask ComputeNode where(each.id=computenode_id) {
                s_num <- self.attrs["AMOUNT_SENSORS"];
                a_num <- self.attrs["AMOUNT_ACTUATORS"];
            }
            //ask ComputeNode

            if s_num=0 and a_num=0 { //si no tiene satélites ("S:|A:")
                //para poder foldear...
                //este if nomás existe para librarla si no tiene satélites
            }else if a_num=0 { //si sólo tiene sensores ("S:12,14,17|A:")

                satellite_str <- replace(satellite_str, "S:",  "");
                satellite_str <- replace(satellite_str, "|A:", "");

                list_of_sensors_str <- satellite_str split_with(",");
            }else if s_num=0 { //si sólo tiene actuadores ("S:|A:16,69")

                satellite_str <- replace(satellite_str, "S:|A:", "");

                list_of_actuators_str <- satellite_str split_with(",");
            }else { //si tiene de ambos satélites ("S:12,14,17|A:16,69")

                satellite_str <- replace(satellite_str, "S:", "");
                satellite_str <- replace(satellite_str, "A:", "");

                list<string> satellite_arr <- satellite_str split_with("|");

                list_of_sensors_str   <- satellite_arr[0] split_with(",");
                list_of_actuators_str <- satellite_arr[1] split_with(",");
            }
            //if-else

			//armar listas de sensores y actuadores

            loop s_id over:list_of_sensors_str {
                add int(s_id) to:new_child_sensors;
            }
            //loop s

            loop a_id over:list_of_actuators_str {
                add int(a_id) to:new_child_actuators;
            }
            //loop a

			//guardar nuevas listas de sensores y actuadores
            ask ComputeNode where(each.id=computenode_id) {
                //write "OUT of CN "+self.id+" attempting to refresh lists with "+new_child_sensors+" and "+new_child_actuators; //descomentar para debuggear
                do refreshSatLists(new_child_sensors, new_child_actuators);
            }
            //ask ComputeNode

			//actualizar las posiciones de los agentes en la simulación
			ask Sensor      {do refreshLocation();}
			ask Actuator    {do refreshLocation();}
			ask ComputeNode {do refreshSatPlaces();}

            //write "CN "+computenode_id+"'s sensors/actuators refreshed.";
            return;
        }
        //refreshSatellites

        //Según el estado completo del ledger, actualizar todo el sistema
        action refreshAll(string systemstate) {

            //declare empty containers

            list<string> system_state   <- [];
            list<string> all_infos_list <- [];
            list<string> all_sats_list  <- [];
            list<string> info_pair      <- [];
            list<string> sat_pair       <- [];

            string device_str     <- "";

            map<int,string> all_infos <- [];
            map<int,string> all_sats  <- [];

            //write "systemstate at refreshAll is: ["+systemstate+"]"; //descomentar para debuggear

            if systemstate!="&" {

                //systemstate en este punto es algo así:
                //"dev_str*id?dev_info%id?dev_info%id?dev_info*id?sat_str%id?sat_str%id?sat_str!"

                //split state data
                system_state <- systemstate split_with("*");

                //get device string
                device_str <- system_state[0];

                //get list of strings from device infos
                all_infos_list <- system_state[1] split_with("%");

                //map info strings to device id
                loop d over:all_infos_list {
                    info_pair <- d split_with("?");
                    all_infos[int(info_pair[0])] <- info_pair[1];
                }
                //loop infos

				write "system_state is: "+system_state;

                //si no hay CN's, system_state[2] es un ampersand
                if( system_state[2] != "&" ) {
                    //get list of strings from sats
                    all_sats_list <- (system_state[2] split_with("%"));
                }
                //if system_state

                //map satellite strings to device id
                loop d over:all_sats_list {
                    sat_pair <- d split_with("?");
                    all_sats[int(sat_pair[0])] <- sat_pair[1];
                }
                //loop sats
            }
            //if systemstate!=""

            //perform GAMA state refreshes

            do refreshDevices(device_str);

            loop dev_id over:all_infos.keys {
                do refreshAttributes(dev_id, all_infos[dev_id]);
            }
            //loop

            loop cn_id over:all_sats.keys {
                do refreshSatellites(cn_id, all_sats[cn_id]);
            }
            //loop

            //write "System's full state refreshed.";
            return;
        }
        //refreshAll
    ////

    ///////////////////////////////////////////////////////////////////////////
    //--VALIDATORS------------------------------------------------------------

        //validadores para textfields:

        bool validateType(string devtype) {
            if devtype in ["1", "2", "3"] {
                return true;
            }else {
                return false;
            }
            //if-else
        }
        //validateType

        bool validateDeviceID(string devid) {
            if computeNodeExists(int(devid)) or sensorExists(int(devid)) or actuatorExists(int(devid)) {
                return true;
            }else {
                return false;
            }
            //if-else
        }
        //validateDeviceID

        bool validateCNID(string cnid) {
            if computeNodeExists(int(cnid)) {
                return true;
            }else {
                return false;
            }
            //if-else
        }
        //validateCNID

        bool validateSatelliteID(string satid) {
            if sensorExists(int(satid)) or actuatorExists(int(satid)) {
                return true;
            }else {
                return false;
            }
            //if-else
        }
        //validateSatelliteID

        bool validatePublicKey(string pkey) {
            if int(pkey)>=1000 and int(pkey)<=9999 {
                return true;
            }else {
                return false;
            }
            //if-else
        }
        //validatePublicKey

        bool validateThreshold(string th) {
            if (int(th) >= th_low_bound) and (int(th) <= th_high_bound) {
                return true;
            }else {
                return false;
            }
            //if-else
        }
        //validateThreshold

        bool hasParent(string satid) {

            if not(validateSatelliteID(satid)) {return false;}

            int parentcn1 <- ckeytonumber["DEFAULT"];
            int parentcn2 <- ckeytonumber["DEFAULT"];

            ask Sensor   where(each.id=int(satid)) {parentcn1 <- self.attrs["PARENT"];}
            ask Actuator where(each.id=int(satid)) {parentcn2 <- self.attrs["PARENT"];}

            if (parentcn1 = ckeytonumber["DEFAULT"]) and (parentcn2 = ckeytonumber["DEFAULT"]) {return false;}

            return true;
        }
        //hasParent

        bool areRelated(string satid, string cnid) {

            int parentid1 <- ckeytonumber["DEFAULT"];
            int parentid2 <- ckeytonumber["DEFAULT"];

            ask Sensor   where(each.id=int(satid)) {parentid1 <- self.attrs["PARENT"];}
            ask Actuator where(each.id=int(satid)) {parentid2 <- self.attrs["PARENT"];}

            if parentid1=int(cnid) or parentid2=int(cnid) {
                return true;
            }else {
                return false;
            }
            //if-else
        }
        //areRelated

        bool canHaveChildren(string cnid) {

            int num_s <- 0;
            int num_a <- 0;

            ask ComputeNode where(each.id=int(cnid)) {
                num_s <- self.attrs["AMOUNT_SENSORS"];
                num_a <- self.attrs["AMOUNT_ACTUATORS"];
            }
            //ask ComputeNode

            if( (num_s+num_a) >= satellitelimit ) {return false;}

            return true;
        }
        //canHaveChildren

        bool parentIsAble(int satid) {

            bool able;
            string devtype <- getDeviceType(satid);

            switch devtype {

                match "1" { //sensor
                    ask Sensor   where(each.id=satid) {able <- self.parentIsOperational();}
                    break;
                }
                match "2" { //actuator
                    ask Actuator where(each.id=satid) {able <- self.parentIsOperational();}
                    break;
                }
                match "3" { //compute node
                    able <- true;
                    break;
                }
                //match
            }
            //switch devtype

            return able;
        }
        //parentIsAble
    ////

    ///////////////////////////////////////////////////////////////////////////
    //--HANDLERS--------------------------------------------------------------

        action PingBackEndHandler {
            //nada que validar...
            do outgoingMessage("pingBackEnd");
            return;
        }
        //PingBackEndHandler

        action CreateNewDeviceHandler {

            if not(validateType(createDevice_tipo)) { //que el tipo exista
                write "Input ERROR at CreateNewDevice: ["+createDevice_tipo+"] is not a valid type.";
                return;
            }
            //if validateType

            if deviceAmount() >= devicelimit { //que no hayan demasiados devices ya
                write "Input ERROR at CreateNewDevice: too many devices already created.";
                return;
            }
            //if deviceAmount

			/*
			switch createDevice_tipo {
				match "3" { //compute node
					if(length(ComputeNode) >= cn_limit) {
						write "Input ERROR at CreateNewDevice: too many Compute Nodes already created.";
                		return;
					}
					//if
					break;
				}
				match_one ["1","2"] { //sensor o actuador
					if( (length(Sensor) + length(Actuator)) >= satellitelimit ) {
						write "Input ERROR at CreateNewDevice: too many Satellites already created.";
                		return;
					}
					//if
					break;
				}
				//match
			}
			//switch createDevice_tipo
			*/
			//

            do outgoingMessage("createDevice");
            return;
        }
        //CreateNewDeviceHandler

        action ReplaceSatelliteHandler {

            if not(validateSatelliteID(replaceDevice_sa_id)) { //que el satellite exista
                write "Input ERROR at ReplaceSatellite: Sensor/Actuator ["+replaceDevice_sa_id+"] not found.";
                return;
            }
            //if validateSatelliteID

            if not(hasParent(replaceDevice_sa_id)) { //que tenga padre
                write "Input ERROR at ReplaceSatellite: Sensor/Actuator ["+replaceDevice_sa_id+"] has no Compute Node.";
                return;
            }
            //if hasParent

            if deviceAmount() >= devicelimit { //que no hayan 14 devices creados
                write "Input ERROR at ReplaceSatellite: too many devices already created.";
                return;
            }
            //if deviceAmount

            do outgoingMessage("replaceDevice");
            return;
        }
        //ReplaceSatelliteHandler

        action DeleteSatelliteHandler {

            if not(validateSatelliteID(destroySatellite_sa_id)) { //que el satellite exista
                write "Input ERROR at DeleteSatellite: Sensor/Actuator ["+destroySatellite_sa_id+"] not found.";
                return;
            }
            //if validateSatelliteID

            do outgoingMessage("destroySatellite");
            return;
        }
        //DeleteSatelliteHandler

        action DeleteCNHandler {

            if not(validateCNID(destroyComputeNode_cn_id)) { //que exista el CN
                write "Input ERROR at DeleteCN: Compute Node ["+destroyComputeNode_cn_id+"] not found.";
                return;
            }
            //if validateCNID

            do outgoingMessage("destroyComputeNode");
            return;
        }
        //DeleteCNHandler

        action ResetSystemHandler {

            if deviceAmount() = 0 { //que hayan devices
                write "Input ERROR at ResetSystem: no devices found.";
                return;
            }
            //if deviceAmount

            do outgoingMessage("deleteAllDevices");
            return;
        }
        //ResetSystemHandler

        action UnlinkSatelliteHandler {

            if not(validateSatelliteID(unlinkSubDevice_sa_id)) { //que el satellite exista
                write "Input ERROR at UnlinkSatellite: Sensor/Actuator ["+unlinkSubDevice_sa_id+"] not found.";
                return;
            }
            //if validateSatelliteID

            if not(hasParent(unlinkSubDevice_sa_id)) { //que tenga padre
                write "Input ERROR at UnlinkSatellite: Sensor/Actuator ["+unlinkSubDevice_sa_id+"] has no Compute Node.";
                return;
            }
            //if hasParent

            do outgoingMessage("unlinkSubDevice");
            return;
        }
        //UnlinkSatelliteHandler

        action LinkSatelliteHandler {

            if not(validateSatelliteID(linkDeviceToComputeNode_sa_id)) { //que el sat exista
                write "Input ERROR at LinkSatellite: Sensor/Actuator ["+linkDeviceToComputeNode_sa_id+"] not found.";
                return;
            }
            //if validateSatelliteID

            if not(validateCNID(linkDeviceToComputeNode_new_cn)) { //que el cn exista
                write "Input ERROR at LinkSatellite: Compute Node ["+linkDeviceToComputeNode_new_cn+"] not found.";
                return;
            }
            //if validateCNID

            if hasParent(linkDeviceToComputeNode_sa_id) { //que no tenga padre
                write "Input ERROR at LinkSatellite: Sensor/Actuator ["+linkDeviceToComputeNode_sa_id+"] already has a Compute Node.";
                return;
            }
            //if hasParent

            if not(canHaveChildren(linkDeviceToComputeNode_new_cn)) { //que el cn no tenga 13 hijos
                write "Input ERROR at LinkSatellite: Compute Node ["+linkDeviceToComputeNode_new_cn+"] can't have any more linked devices.";
                return;
            }
            //if canHaveChildren

            do outgoingMessage("linkDeviceToComputeNode");
            return;
        }
        //LinkSatelliteHandler

        action ResetDeviceHandler {

            if not(validateDeviceID(applyDefaultConfig_device_id)) { //que el device exista
                write "Input ERROR at ResetDevice: Device ["+applyDefaultConfig_device_id+"] not found.";
                return;
            }
            //if validateDeviceID

            applyDefaultConfig_tipo <- getDeviceType(int(applyDefaultConfig_device_id));

            do outgoingMessage("applyDefaultConfig");
            return;
        }
        //ResetDeviceHandler

        action SetPublicKeyHandler {

            if not(validateDeviceID(setPublicKey_device_id)) { //que el device exista
                write "Input ERROR at SetPublicKey: Device ["+setPublicKey_device_id+"] not found.";
                return;
            }
            //if validateDeviceID

            if not(validatePublicKey(setPublicKey_config_value)) { //que la llave esté dentro del rango
                write "Input ERROR at SetPublicKey: Public key ["+setPublicKey_config_value+"] out of range [1000,9999].";
                return;
            }
            //if validatePublicKey

            do outgoingMessage("setPublicKey");
            return;
        }
        //SetPublicKeyHandler

        action SetThresholdHandler {

            if not(validateCNID(setThreshold_cn_id)) { //que el cn exista
                write "Input ERROR at SetThreshold: Compute Node ["+setThreshold_cn_id+"] not found.";
                return;
            }
            //if validateDeviceID

            if not(validateThreshold(setThreshold_config_value)) { //que el threshold esté dentro del rango
                write "Input ERROR at SetThreshold: Threshold ["+setThreshold_config_value+"] out of range ["+th_low_bound+","+th_high_bound+"].";
                return;
            }
            //if validateThreshold

            do outgoingMessage("setThreshold");
            return;
        }
        //SetThresholdHandler

        action GrantPermissionsHandler {

            if not(validateDeviceID(grantPerms_device_id)) { //que el device exista
                write "Input ERROR at GrantPermissions: Device ["+grantPerms_device_id+"] not found.";
                return;
            }
            //if validateDeviceID

            if not(parentIsAble(int(grantPerms_device_id))) { //que el CN padre esté habilitado
                write "Input ERROR at GrantPermissions: Device ["+grantPerms_device_id+"]'s Compute Node is not operational.";
                return;
            }
            //if parentIsAble

            do outgoingMessage("grantPerms");
            return;
        }
        //GrantPermissionsHandler

        action DenyPermissionsHandler {

            if not(validateDeviceID(denyPerms_device_id)) { //que el device exista
                write "Input ERROR at DenyPermissions: Device ["+denyPerms_device_id+"] not found.";
                return;
            }
            //if validateDeviceID

            do outgoingMessage("denyPerms");
            return;
        }
        //DenyPermissionsHandler

        action TurnDeviceOnHandler {

            if not(validateDeviceID(turnOnDevice_device_id)) { //que el device exista
                write "Input ERROR at TurnDeviceOn: Device ["+turnOnDevice_device_id+"] not found.";
                return;
            }
            //if validateDeviceID

            if not(parentIsAble(int(turnOnDevice_device_id))) { //que el CN padre esté habilitado
                write "Input ERROR at TurnDeviceOn: Device ["+turnOnDevice_device_id+"]'s Compute Node is not operational.";
                return;
            }
            //if parentIsAble

            do outgoingMessage("turnOnDevice");
            return;
        }
        //TurnDeviceOnHandler

        action TurnDeviceOffHandler {

            if not(validateDeviceID(turnOffDevice_device_id)) { //que el device exista
                write "Input ERROR at TurnDeviceOff: Device ["+turnOffDevice_device_id+"] not found.";
                return;
            }
            //if validateDeviceID

            do outgoingMessage("turnOffDevice");
            return;
        }
        //TurnDeviceOffHandler

        action TurnEverythingOnHandler {

            if deviceAmount() = 0 { //que hayan devices
                write "Input ERROR at TurnEverythingOn: no devices found.";
                return;
            }
            //if deviceAmount

            do outgoingMessage("turnOnAllDevices");
            return;
        }
        //TurnEverythingOnHandler

        action TurnEverythingOffHandler {

            if deviceAmount() = 0 { //que hayan devices
                write "Input ERROR at TurnEverythingOff: no devices found.";
                return;
            }
            //if deviceAmount

            do outgoingMessage("turnOffAllDevices");
            return;
        }
        //TurnEverythingOffHandler
    ////

    ///////////////////////////////////////////////////////////////////////////
    //--COMMUNICATION HANDLERS------------------------------------------------

        //aquí está el sendToETH
        action outgoingMessage(string func) { //request

            string msg_to_send <- "";

            switch func {

                match "pingBackEnd"             {msg_to_send <- "pingBackEnd"; break;}
                match "createDevice"            {msg_to_send <- "createDevice/"+createDevice_tipo; break;}
                match "replaceDevice"           {msg_to_send <- "replaceDevice/"+replaceDevice_sa_id; break;}
                match "destroySatellite"        {msg_to_send <- "destroySatellite/"+destroySatellite_sa_id; break;}
                match "destroyComputeNode"      {msg_to_send <- "destroyComputeNode/"+destroyComputeNode_cn_id; break;}
                match "deleteAllDevices"        {msg_to_send <- "deleteAllDevices"; break;}
                match "unlinkSubDevice"         {msg_to_send <- "unlinkSubDevice/"+unlinkSubDevice_sa_id; break;}
                match "linkDeviceToComputeNode" {msg_to_send <- "linkDeviceToComputeNode/"+linkDeviceToComputeNode_sa_id+"/"+linkDeviceToComputeNode_new_cn; break;}
                match "applyDefaultConfig"      {msg_to_send <- "applyDefaultConfig/"+applyDefaultConfig_device_id+"/"+applyDefaultConfig_tipo; break;}
                match "setPublicKey"            {msg_to_send <- "setPublicKey/"+setPublicKey_device_id+"/"+setPublicKey_config_value; break;}
                match "setThreshold"            {msg_to_send <- "setThreshold/"+setThreshold_cn_id+"/"+setThreshold_config_value; break;}
                match "grantPerms"              {msg_to_send <- "grantPerms/"+grantPerms_device_id; break;}
                match "denyPerms"               {msg_to_send <- "denyPerms/"+denyPerms_device_id; break;}
                match "turnOnDevice"            {msg_to_send <- "turnOnDevice/"+turnOnDevice_device_id; break;}
                match "turnOffDevice"           {msg_to_send <- "turnOffDevice/"+turnOffDevice_device_id; break;}
                match "turnOnAllDevices"        {msg_to_send <- "turnOnAllDevices"; break;}
                match "turnOffAllDevices"       {msg_to_send <- "turnOffAllDevices"; break;}

                default {return;}
            }
            //switch func

            string waitstr <- "ESPERANDO (3) en outgoingMessage al response del último request...";
            do pickTCPAndSend(msg_to_send, waitstr);
            return;
        }
        //action outgoingMessages

        //aquí está el refreshAll
        action incomingMessage(string res) { //response

            list<string> func_result <- res split_with("/");

            switch func_result[0] {

                //---------------------------------------------------------------------------------------------------
                //AUTOMATICS

                match "refreshAll" { //call

                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = RETURNS(string statelist)

                    //write "Updated system state is: ["+func_result[1]+"]"; //descomentar para debuggear

                    do refreshAll(func_result[1]); //aplicar el estado del ledger
                    write "Refreshed system state.\n\n--------------------------------------------------------------------";

                    //saber si se harán loggings y eval de las lecturas
                    cns_will_log  <- 0;
                    cns_will_eval <- 0;
                    ask ComputeNode {
                        cns_will_log <- cns_will_log + self.willLogReadings(); //aquí se transfieren las lecturas de los sensores a los CNs
                        if(self.willEvalReadings()) {cns_will_eval <- cns_will_eval+1;}
                    }
                    //ask Computenode

                    if(cns_will_log=0 and cns_will_eval=0) {
                    	do showSummary();
                    	do spawnSummaries();
                        write "\n--------------------------------------------------------------------";
                        write "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
                        write "!!! YOU CAN SEND COMMANDS NOW !!!";
                        write "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
                        showcounter <- true;
                    }
                    //if cns_will_log and cns_will_eval

                    //logging de las lecturas
                    if(cns_will_log > 0) {
                        ask ComputeNode {do logReadings;} //aquí se llama a uploadReading N veces (una por cada Sensor)
                        write "";
                    }
                    //if cns_will_log

                    //comandar a los actuadores según las lecturas
                    if(cns_will_eval > 0) {
                        ask ComputeNode {do evalReadings;} //aquí se llama a evalSensors N veces (una por cada CN)
                        write "";
                    }
                    //if cns_will_eval

                    break;
                }
                //refreshAll
                match "uploadReading" { //se ejecuta una vez por cada sensor

                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = uploadReading_cn_id
                    //func_result[2] = uploadReading_sa_id
                    //func_result[3] = uploadReading_reading
                    //func_result[4] = RETURNS(int reading)

                    write "Uploaded reading of Sensor "+func_result[2]+" with value "+func_result[4]+"\n";

                    cns_will_log <- cns_will_log-1;
                    if(cns_will_log=0 and cns_will_eval=0) {
                    	do showSummary();
                    	do spawnSummaries();
                        write "\n--------------------------------------------------------------------";
                        write "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
                        write "!!! YOU CAN SEND COMMANDS NOW !!!";
                        write "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
                        showcounter <- true;
                    }
                    //if cns_will_log and cns_will_eval

                    break;
                }
                //uploadReading
                match "evalSensors" { //se ejecuta una vez por cada CN

                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = evalSensors_cn_id
                    //func_result[2] = RETURNS(int act_command)

                    write "Updated Actuators of Compute Node "+func_result[1]+" with command "+ckeytoname[int(func_result[2])]+"\n";

                    //trata la respuesta, que puede ser:
                    //int(func_result[2]) =  0 = no cambiar nada
                    //int(func_result[2]) = 10 = mandar a los actuadores a detenerse
                    //int(func_result[2]) = 11 = mandar a los actuadores a actuar

                    ask ComputeNode where(each.id=int(func_result[1])) {
                        do commandActuators(int(func_result[2]));
                    }
                    //ask ComputeNode

                    cns_will_eval <- cns_will_eval-1;
                    if(cns_will_eval=0) {
                    	do showSummary();
                    	do spawnSummaries();
                        write "\n--------------------------------------------------------------------";
                        write "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
                        write "!!! YOU CAN SEND COMMANDS NOW !!!";
                        write "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
                        showcounter <- true;
                    }
                    //if cns_will_eval

                    break;
                }
                //evalSensors

                //---------------------------------------------------------------------------------------------------
                //MANUALS

                //no action is required after these responses
                //since refreshAll will take care of everything...

                match "pingBackEnd" { //call
                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = RETURNS(bool success)
                    if func_result[1]="True" {write "Ledger and Bridge are ONLINE.";}
                    break;
                }
                //pingBackEnd
                match "createDevice" {
                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = createDevice_tipo
                    //func_result[2] = RETURNS(int latestid)
                    string typestr <- ckeytoname[int(func_result[1])];
                    write "New "+typestr+" created with ID "+func_result[2];
                    break;
                }
                //createDevice
                match "replaceDevice" {
                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = replaceDevice_sa_id
                    //func_result[2] = RETURNS(int latestid)
                    write "Replaced device "+func_result[1]+" with new device "+func_result[2];
                    break;
                }
                //replaceDevice
                match "destroySatellite" {
                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = destroySatellite_device_id
                    //func_result[2] = RETURNS(string devicelist)
                    write "Destroyed device "+func_result[1]+". Updated list of devices is: "+func_result[2];
                    break;
                }
                //destroySatellite
                match "destroyComputeNode" {
                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = destroyComputeNode_device_id
                    //func_result[2] = RETURNS(string devicelist)
                    write "Destroyed Compute Node "+func_result[1]+". Updated list of devices is: "+func_result[2];
                    break;
                }
                //destroyComputeNode
                match "deleteAllDevices" {
                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = RETURNS(string devicelist)
                    write "All devices deleted. Updated list of devices is: "+func_result[1];
                    break;
                }
                //deleteAllDevices
                match "unlinkSubDevice" {
                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = unlinkSubDevice_sa_id
                    //func_result[2] = RETURNS(int configval)
                    write "Device "+func_result[1]+" unlinked from Compute Node.";
                    break;
                }
                //unlinkSubDevice
                match "linkDeviceToComputeNode" {
                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = linkDeviceToComputeNode_sa_id
                    //func_result[2] = linkDeviceToComputeNode_new_cn
                    //func_result[3] = RETURNS(int configval)
                    write "Device "+func_result[1]+" linked to Compute Node "+func_result[3];
                    break;
                }
                //linkDeviceToComputeNode
                match "applyDefaultConfig" {
                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = applyDefaultConfig_device_id
                    //func_result[2] = applyDefaultConfig_tipo
                    //func_result[3] = RETURNS(string devicedata)
                    write "Config values of device "+func_result[1]+" were reset to "+func_result[3];
                    break;
                }
                //applyDefaultConfig
                match "setPublicKey" {
                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = setPublicKey_device_id
                    //func_result[2] = setPublicKey_config_value
                    //func_result[3] = RETURNS(int configval)
                    write "Device "+func_result[1]+"'s public key set to "+func_result[3];
                    break;
                }
                //setPublicKey
                match "setThreshold" {
                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = setThreshold_cn_id
                    //func_result[2] = setThreshold_config_value
                    //func_result[3] = RETURNS(int configval)
                    write "Compute Node "+func_result[1]+"'s threshold set to "+func_result[3];
                    break;
                }
                //setThreshold
                match "grantPerms" {
                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = grantPerms_device_id
                    //func_result[2] = RETURNS(int configval)
                    string valstr <- ckeytoname[int(func_result[2])];
                    write "Device "+func_result[1]+"'s Updated permissions are: "+valstr;
                    break;
                }
                //grantPerms
                match "denyPerms" {
                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = denyPerms_device_id
                    //func_result[2] = RETURNS(int configval)
                    string valstr <- ckeytoname[int(func_result[2])];
                    write "Device "+func_result[1]+"'s Updated permissions are: "+valstr;
                    break;
                }
                //denyPerms
                match "turnOnDevice" {
                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = turnOnDevice_device_id
                    //func_result[2] = RETURNS(int configval)
                    string valstr <- ckeytoname[int(func_result[2])];
                    write "Device "+func_result[1]+"'s Updated status is: "+valstr;
                    break;
                }
                //turnOnDevice
                match "turnOffDevice" {
                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = turnOffDevice_device_id
                    //func_result[2] = RETURNS(int configval)
                    string valstr <- ckeytoname[int(func_result[2])];
                    write "Device "+func_result[1]+"'s Updated status is: "+valstr;
                    break;
                }
                //turnOffDevice
                match "turnOnAllDevices" {
                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = RETURNS(bool success)
                    if(func_result[1]="True") {write "All devices turned ON.";}
                    break;
                }
                //turnOnAllDevices
                match "turnOffAllDevices" {
                    //func_result[0] = FUNCTION_NAME
                    //func_result[1] = RETURNS(bool success)
                    if(func_result[1]="True") {write "All devices turned OFF.";}
                    break;
                }
                //turnOffAllDevices

                default {
                	write "UDP Response message is not recognized...";
                	break;
                }
                //default
            }
            //switch

            return;
        }
        //action incomingMessage
    ////

    ///////////////////////////////////////////////////////////////////////////
    //--MAIN REFRESH REFLEX---------------------------------------------------

        reflex countDownCycles {
            if(showcounter) {write ""+(cyclestoloop - counterdown - 1)+"...";}
            counterdown <- (cycle mod cyclestoloop);
            return;
        }
        //reflex countDownCycles

        //si quieres detener el loop principal cambia el when de arriba por: when:false
        reflex stateRefresher when:every(cyclestoloop#cycle) {

            //sólo pasa de aquí si ya se recibió y procesó el response a todos los requests anteriores
            if not(got_response) {return;} //si estamos esperando algún response, nos brincamos este ciclo de refresh
            refreshcounter <- refreshcounter+1;
            write "\n--------------------------------------------------------------------";
            string waitstr <- "ESPERANDO (4) en stateRefresher al response del último request...";
            do pickTCPAndSend("refreshAll", waitstr);
        }
        //reflex stateRefresher
    ////

    ///////////////////////////////////////////////////////////////////////////
    //--INITIALIZE------------------------------------------------------------

        init {

            write "Attempting to setup TCP Agents...";

            //los agentes de la especie TCP_Client son capaces de usar network y do connect
            create TCP_Client number:tcpclients {

                simulation_id <- simulation_id+1;
                name <- prefix_client + string(simulation_id); //le pone nombres únicos autoincrementados a los agentes cliente

                do connect to:"127.0.0.1" protocol:"tcp_client" port:9999 with_name:"Client"; //datos de conexión con el server de python
            }
            //create TCP_Client

            tcps <- (agents of_species TCP_Client);

            write "Attempting to setup a UDP Agent...";

            //los agentes de la especie UDP_Server son capaces de usar network y do connect
            create UDP_Server number:1 {
                //para poder foldear...
                do connect to:"127.0.0.1" protocol:"udp_server" port:9877; //datos de conexión con esta simulación de GAMA
            }
            //create UDP_Server

            create AmbientLight number:spotlights;
            create BorderLine number:1;

            write "TCP & UDP Agents are ready.\n";
            write "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
            write "!!! REMEMBER TO SET SPEED TO MINIMUM !!!";
            write "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!";
            write "\nHit play to start.\n";
        }
        //init
    ////
}
//global

//Especie que envía mensajes al server de python
species TCP_Client skills:[network] {

    string name;
    bool free;

    init {
        self.free <- true;
    }
    //init

    //str_to_send es el mensaje que enviamos a python, ya debe venir listo para enviarse
    action sendToETH(string str_to_send, string waitmsg) {

        showcounter <- false;
        self.free   <- false;

        //write waitmsg;
        //loop while:true {if(got_response) {break;}} //esperar a que no hayan más requests para enviar el siguiente
        //write "REACHED (TCP)! ("+(waitmsg at 11)+")";
        got_response <- false; //a partir de este momento no se vale lanzar más requests que el de aquí abajo

        string curr_time <- "";
        ask world {curr_time <- getMachineTime();}
        write "TCP Request sent at "+curr_time+": ["+str_to_send+"]"; //descomentar para debuggear
        do send contents:str_to_send; //send es un método sacado de network que envía el mensaje a python

        self.free <- true;
    }
    //action sendToETH
}
//species TCP_Client

//Especie que recibe mensajes desde el server de python
species UDP_Server skills:[network] {

    string msg <- "";
    string buffer <- "";

    //hace esto siempre que haya recibido texto y no lo haya leído todo
    reflex fetch when:has_more_message() {

        string curr_time <- "";

        loop while:has_more_message() {

			//todos los mensajes recibidos llegan con "!!" o "!" al final.
			//si tienen "!!" es que falta más mensaje después del que acaba de llegar, entonces appendar en un buffer lo que recibamos.
			//si tienen "!" es que el mensaje ya llegó completo, entonces appendar al buffer y procesarlo normalmente.

            self.msg <- "";
            message s <- fetch_message(); //guarda en s el mensaje recibido

			write "I just got: ["+string(s.contents)+"]"; //descomentar para debuggear

			if("!!" in string(s.contents)) { //el mensaje aún no termina, necesitas el siguiente pedazo

				//remover caracteres basura a la derecha y appendar al buffer
				ask world {myself.msg <- removeRemainder(string(s.contents));}
				self.buffer <- (self.buffer + self.msg);

				//got_response <- true; //ya se puede lanzar otro request
			}else if("!" in string(s.contents)) { //el mensaje ya llegó completo, procesarlo normalmente

				//remover caracteres basura a la derecha y preppendarle el buffer
				ask world {myself.msg <- removeRemainder(string(s.contents));}
				self.msg <- (self.buffer + self.msg);
				self.buffer <- "";

	            //armar el mensaje de respuesta para la consola
	            ask world {curr_time <- getMachineTime();}
	            write "UDP Response got at "+curr_time+": ["+self.msg+"]"; //pone el mensaje enviado en la terminal de GAMA

				//mandar a procesar el mensaje normalmente
				got_response <- true; //ya se puede lanzar otro request
	            ask world {do incomingMessage(myself.msg);}
			}else { //el mensaje viene mal formado, ignorarlo

				//avisar al usuario e ignorar
				write "UDP Response ERROR. Message is malformed.";
				self.buffer <- "";

				got_response <- true; //ya se puede lanzar otro request
			}
			//if-else
        }
        //loop while
    }
    //reflex fetch
}
//species UDP_Server

species SummaryContainer {

	string summarystr;

	aspect default {
		draw(summarystr) color:#black;
	}
	//aspect default
}
//SummaryContainer

species BorderLine {
	aspect default {
        draw polyline([{ 0.1 ,  0.1} , { 0.1 , 99.9}]) color:#black end_arrow:0;
        draw polyline([{ 0.1 ,  0.1} , {99.9 ,  0.1}]) color:#black end_arrow:0;
        draw polyline([{99.9 , 99.9} , { 0.1 , 99.9}]) color:#black end_arrow:0;
        draw polyline([{99.9 , 99.9} , {99.9 ,  0.1}]) color:#black end_arrow:0;
	}
    //aspect default
}
//AmbientLight

species AmbientLight skills:[moving] {

	bool moving;

    init {
    	self.moving <- true;
        self.speed  <- spotlight_speed;
    }
    //init

    reflex move when:self.moving {
        do wander amplitude:90.0 speed:self.speed;
    }
    //move

	action toggleMovement {
		self.moving <- not(self.moving);
	}
	//toggleMovement

    aspect default {
        draw circle(spotlight_radius) color:#yellow;
    }
    //aspect default
}
//AmbientLight

species Device {

    int id;
    string type;
    string idstring;

    map<string,int> attrs <- [
        "ID"            :: self.id,
        "TYPE"          :: ckeytonumber[self.type],
        "PUBLIC_KEY"    :: ckeytonumber["DEFAULT"],
        "PERMISSION"    :: ckeytonumber["LOW"],
        "ON_OFF_STATUS" :: ckeytonumber["LOW"]
    ];
    //attrs

	init {
		self.location <- {0,0};
		self.idstring <- "--- "+self.id;
	}
	//init

	action resetLocation {
		self.location <- {0,0};
	}
	//resetLocation

	action showUp {return;} //sólo para overwritearlo en las species hijos
    bool isOperational {return false;} //sólo para overwritearlo en las species hijos
}
//species Device

species ComputeNode parent:Device {

    list<int> child_sensors;
    list<int> child_actuators;

    map<int,int> subsensor_readings <- [];
    bool actuator_commands <- false;

	map<point,bool> satplaces <- [];

    init {
        self.child_sensors             <- [];
        self.child_actuators           <- [];
        self.attrs["AMOUNT_SENSORS"]   <- ckeytonumber["DEFAULT"];
        self.attrs["AMOUNT_ACTUATORS"] <- ckeytonumber["DEFAULT"];
        self.attrs["THRESHOLD"]        <- ckeytonumber["DEFAULT"];

        do setCNLocation();
        do setSatPlaces();
    }
    //init

    string showUp {
        string mapstr;
        ask world {mapstr <- prettyPrintAttrs(myself.attrs);}
        mapstr <- mapstr + " -- S: "+child_sensors+", -- A: "+child_actuators;
        add mapstr to:summary;
        return mapstr;
    }
    //showUp

    action refreshSatLists(list<int> cs, list<int> ca) {
        //write "IN CN "+self.id+" attempting to refresh lists with "+cs+" and "+ca; //descomentar para debuggear
        self.child_sensors   <- cs;
        self.child_actuators <- ca;
        return;
    }
    //refreshSatLists

    bool isOperational {

        //don't operate if off, unpermissioned or without a threshold
        if (self.attrs["THRESHOLD"]     = ckeytonumber["DEFAULT"]) {return false;} //not if threshold isn't set
        if (self.attrs["PERMISSION"]    < ckeytonumber["HIGH"])    {return false;} //not without permission
        if (self.attrs["ON_OFF_STATUS"] < ckeytonumber["HIGH"])    {return false;} //not while off

        return true;
    }
    //isOperational

    bool sensorIsOperational(int sensorid) {

        bool sensor_is_able <- true;

        ask Sensor where(each.id=sensorid) {
            sensor_is_able <- self.isOperational();
        }
        //ask Sensor

        return sensor_is_able;
    }
    //sensorIsOperational

    bool actuatorIsOperational(int actuatorid) {

        bool actuator_is_able <- true;

        ask Actuator where(each.id=actuatorid) {
            actuator_is_able <- self.isOperational();
        }
        //ask Actuator

        return actuator_is_able;
    }
    //actuatorIsOperational

    action printReadings {
        if(not(self.isOperational())) {return;} //no hacer nada si el CN no está habilitado
        write "\nCompute Node "+self.id+" reports readings: "+self.subsensor_readings+"\n";
        return;
    }
    //printReadings

    action gatherReadings {

        //write "child sensors of CN "+self.id+": "+child_sensors; //descomentar para debuggear

        self.subsensor_readings <- [];

        ask Sensor where(each.id in child_sensors) {
            myself.subsensor_readings[self.id] <- self.reading;
        }
        //ask Sensor

        //do printReadings(); //descomentar para debuggear

        return;
    }
    //gatherReadings

    int willLogReadings {

        int countreadings <- 0;

        if(not(self.isOperational())) {return countreadings;} //no hacer nada si el CN no está habilitado

        do gatherReadings(); //actualizar las lecturas de los sensores que existen, borrar las demás

        loop sensorid over:self.subsensor_readings.keys { //no hará ni un loop si el CN no tiene sensores
            //con cada sensor que pueda loggear un reading, contamos un reading más que se escribirá en el ledger
            if self.sensorIsOperational(sensorid) {countreadings <- countreadings+1;}
        }
        //loop

        return countreadings;
    }
    //willLogReadings

    action logReadings {

        if(self.willLogReadings()=0) {return;}

        do printReadings(); //descomentar para debuggear

        loop sensorid over:self.subsensor_readings.keys { //no hará ni un loop si el CN no tiene sensores

            if self.sensorIsOperational(sensorid) { //brincarnos el sensor si no está habilitado

                string msg_to_send <- "uploadReading/"+self.id+"/"+sensorid+"/"+self.subsensor_readings[sensorid];
                string waitstr <- "ESPERANDO (5) en ComputeNode/logReadings al response del último ComputeNode/logReadings o del refreshAll...";
                ask world {do pickTCPAndSend(msg_to_send, waitstr);}
            }
            //if sensorIsOperational
        }
        //loop
    }
    //logReadings

    bool willEvalReadings {

        if(not(self.isOperational())) {return false;} //no hacer nada si el CN no está habilitado
        if(empty(self.child_actuators)) {return false;} //no hacer nada si el CN no tiene actuadores

        return true;
    }
    //willEvalReadings

    action evalReadings {

        if(not(self.willEvalReadings())) {return;}

        string msg_to_send <- "evalSensors/"+self.id;
        string waitstr <- "ESPERANDO (6) en ComputeNode/evalReadings al response del último ComputeNode/uploadReading...";
        ask world {do pickTCPAndSend(msg_to_send, waitstr);}
        return;
    }
    //evalReadings

    action commandActuators(int new_command) {

        //no hacer nada si el CN no está habilitado
        if(not(self.isOperational())) {return;}

        //si el comando no es actuar ni detenerse, dejar los actuadores como están
        if(new_command = ckeytonumber["DEFAULT"]) {return;}

        ask Actuator where(each.id in self.child_actuators) {
            do setAction(new_command);
        }
        //ask Actuator

        return;
    }
    //commandActuators

    //funciones para gráficos--------------------------------------------

    //colocar el CN en uno de los lugares predeterminados
    action setCNLocation {

	    bool  istaken <- true;
	    int   chosenidx;
	    point chosenpoint;

        loop while:istaken { //esto va a tronar como ejote si pretendemos tener más de 9 CNs...
	        chosenidx   <- rnd(0,8);
	        chosenpoint <- places.keys[chosenidx];
	        istaken     <- places[chosenpoint];
        }
        //loop

		self.location <- chosenpoint;
		places[chosenpoint] <- true;

        return;
    }
    //setCNLocation

	action setSatPlaces {

		self.satplaces <- [
			{self.location.x-10 , self.location.y-10} :: false,
			{self.location.x    , self.location.y-10} :: false,
			{self.location.x+10 , self.location.y-10} :: false,
			{self.location.x-10 , self.location.y}    :: false,
			{self.location.x+10 , self.location.y}    :: false,
			{self.location.x-10 , self.location.y+10} :: false,
			{self.location.x    , self.location.y+10} :: false,
			{self.location.x+10 , self.location.y+10} :: false
		];
	}
	//setSatPlaces

	//colocar los sensores y actuadores cerca de su nodo de cómputo
	action setSatLocation(int satid, string sattype) {

        bool  istaken <- true;
        int   chosenidx;
        point chosenpoint;

        loop while:istaken { //esto va a tronar como ejote si pretendemos tener más de 8 Sats x CN...
            chosenidx   <- rnd(0,7);
            chosenpoint <- self.satplaces.keys[chosenidx];
            istaken     <- self.satplaces[chosenpoint];
        }
        //loop

		if(sattype="SENSOR") {
			ask Sensor where(each.id=satid) {self.location <- chosenpoint;}
		}else if(sattype="ACTUATOR") {
			ask Actuator where(each.id=satid) {self.location <- chosenpoint;}
		}
		//if-else

		self.satplaces[chosenpoint] <- true;

		return;
	}
	//setSatLocation

	action freeUpPlace {

		loop i over:self.satplaces.keys {
			self.satplaces[i] <- false;
		}
		//loop

		places[self.location] <- false;
	}
	//freeUpPlace

	action freeUpSatPlace(point loc) {
		//para poder foldear...
		self.satplaces[loc] <- false;
	}
	//freeUpSatPlace

	action refreshSatPlaces {

		list<point> locs <- [];

		//primero obtenemos el location de cada sat conocido

		ask Sensor where(each.id in self.child_sensors) {
			add self.location to:locs;
		}
		//ask

		ask Actuator where(each.id in self.child_actuators) {
			add self.location to:locs;
		}
		//ask

		//luego actualizamos todos los lugares
		loop i over:self.satplaces.keys {

			if(i in locs) {
				self.satplaces[i] <- true;
			}else {
				self.satplaces[i] <- false;
			}
			//if-else
		}
		//loop

		return;
	}
	//refreshSatPlaces

    aspect default {

        if(not(self.isOperational())) {
			draw (self.idstring) color:#black;
            draw compute_node_disabled size:icon_size;
        }else {
        	draw (self.idstring) color:#black;
            draw compute_node size:icon_size;
        }
        //if-else
    }
    //aspect default
}
//species ComputeNode

species Satellite parent:Device {

    int parent;

    init {
        self.attrs["PARENT"] <- ckeytonumber["DEFAULT"];
        parent               <- self.attrs["PARENT"];

        self.location <- {0.0, 0.0}; //posición default para devices sin padre, al cabo no se van a mostrar...
    }
    //init

    action refreshParent {
        //para poder foldear...
        self.parent <- self.attrs["PARENT"];
    }
    //refreshParent

    int getParentThreshold {

        if (self.attrs["PARENT"] = ckeytonumber["DEFAULT"]) {return ckeytonumber["DEFAULT"];}

        int th;
        ask ComputeNode where(each.id=self.attrs["PARENT"]) {
            th <- self.attrs["THRESHOLD"];
        }
        //ask ComputeNode

        return th;
    }
    //getParentThreshold

    bool parentIsOperational {

        if (self.attrs["PARENT"] = ckeytonumber["DEFAULT"]) {return false;}

        bool parentable;
        ask ComputeNode where(each.id=self.attrs["PARENT"]) {
            parentable <- self.isOperational();
        }
        //ask ComputeNode

        return parentable;
    }
    //parentIsOperational

    bool isOperational {

        //don't operate if self or parent is off, unpermissioned or without a threshold
        if (self.attrs["PARENT"]        = ckeytonumber["DEFAULT"]) {return false;} //not without a parent
        if (self.attrs["PERMISSION"]    < ckeytonumber["HIGH"])    {return false;} //not without permission
        if (self.attrs["ON_OFF_STATUS"] < ckeytonumber["HIGH"])    {return false;} //not while off
        if (not(parentIsOperational()))                            {return false;} //not if parent is unable

        return true;
    }
    //isOperational

    //funciones para gráficos--------------------------------------------

    //colocar los sensores y actuadores cerca de su nodo de cómputo
    action setSatLocation {

		if (self.attrs["PARENT"] = ckeytonumber["DEFAULT"]) {return;}

		ask ComputeNode where(each.id=self.parent) {
			do setSatLocation(myself.id, myself.type);
		}
		//ask

		return;
    }
    //setSatLocation

	action freeUpPlace {

		if (self.attrs["PARENT"] = ckeytonumber["DEFAULT"]) {return;}

		ask ComputeNode where(each.id=self.parent) {
			do freeUpSatPlace(myself.location);
		}
		//ask

		return;
	}
	//freeUpPlace

    point getParentLocation {

    	if (self.attrs["PARENT"] = ckeytonumber["DEFAULT"]) {return;}

        point p_loc;
        ask ComputeNode where(each.id=self.parent) {
            p_loc <- self.location;
        }
        return p_loc;
    }
    //getParentLocation

	action refreshLocation {

		//si el sat tiene padre y tiene location
		//dejarlo como está, o se estaría mueve y mueve
		//en cada ciclo de refresh...

		if (self.attrs["PARENT"] = ckeytonumber["DEFAULT"]) {
			//si no tiene padre, resetear su location
			do resetLocation();
		}else if(self.location = {0,0}) {
			//si sí tiene padre y no tiene location, setearle una location
			do setSatLocation();
		}
		//if-else

		return;
	}
	//refreshLocation
}
//species Satellite

species Sensor parent:Satellite {

    int reading; //este se actualiza siempre, basado en la simulación

    init {
        self.reading               <- ckeytonumber["DEFAULT"];
        self.attrs["LAST_READING"] <- ckeytonumber["DEFAULT"]; //este sólo guarda el valor sacado del ledger
    }
    //init

    string showUp { //sensor
        string mapstr;
        ask world {mapstr <- prettyPrintAttrs(myself.attrs);}
        mapstr <- mapstr + " -- " + self.evalThreshold();
        add mapstr to:summary;
        return mapstr;
    }
    //showUp

    string evalThreshold {

        if(not(self.isOperational())) {
            return "<<NOT OPERATIONAL>>";
        }else if(self.reading = ckeytonumber["DEFAULT"]) {
            return "<<NOT OPERATIONAL>>";
        }
        //if-else

        int p_th;
        ask ComputeNode where(each.id=self.parent) {
            p_th <- self.attrs["THRESHOLD"];
        }
        //ask ComputeNode

        if(self.reading > p_th) {
            return ""+self.reading+" HIGHER THAN THRESHOLD "+p_th;
        }else if(self.reading < p_th) {
            return ""+self.reading+" LOWER THAN THRESHOLD "+p_th;
        }else {
            return ""+self.reading+" MATCHES THRESHOLD "+p_th;
        }
        //if-else
    }
    //evalThreshold

    action writeReadingToLedger(int reading_value) {
        string msg_to_send <- "uploadReading/"+self.parent+"/"+self.id+"/"+reading_value;
        string waitstr <- "ESPERANDO (5) en Sensor/writeReadingToLedger al response del último Sensor/writeReadingToLedger o del refreshAll...";
        ask world {do pickTCPAndSend(msg_to_send, waitstr);}
    }
    //writeReadingToLedger

    reflex doReading {

        //aquí va el mecanismo para obtener una lectura del ambiente
        if self.isOperational() {
            //self.reading <- rnd(th_low_bound, th_high_bound); //esto será reemplazado cuando la simulación tenga gráficos
            self.reading <- (empty(AmbientLight at_distance(spotlight_radius)) ? th_low_bound : th_high_bound); //descomentar cuando haya gráficos
        }else {
            self.reading <- ckeytonumber["DEFAULT"];
        }
        //if-else

        return;
    }
    //doReading

    //funciones para gráficos--------------------------------------------

    aspect default {

        int p_th;

        ask ComputeNode where(each.id=self.parent) {
            p_th <- self.attrs["THRESHOLD"];
        }
        //ask ComputeNode

        if(self.parent = ckeytonumber["DEFAULT"]) {
            //no despliegues un satellite sin padre
            do resetLocation();
        }else if(not(self.isOperational())) {
        	draw (self.idstring) color:#black;
            draw sensor_disabled size:icon_size;
        }else if(self.reading > p_th) {
        	draw (self.idstring) color:#black;
            draw sensor_on size:icon_size;
        }else {
        	draw (self.idstring) color:#black;
            draw sensor_off size:icon_size;
        }
        //if-else

        draw polyline([self.location, self.getParentLocation()]) color:#black end_arrow:1;
    }
    //aspect default
}
//species Sensor

species Actuator parent:Satellite {

    bool acting;

    init {
        self.acting               <- false;
        self.attrs["ACT_COMMAND"] <- ckeytonumber["LOW"];
    }
    //init

    string showUp {
        string mapstr;
        ask world {mapstr <- prettyPrintAttrs(myself.attrs);}
        mapstr <- mapstr + " -- " + self.evalActing();
        add mapstr to:summary;
        return mapstr;
    }
    //showUp

    string evalActing {

        if(not(self.isOperational())) {
            return "<<NOT OPERATIONAL>>";
        }else if(self.acting) {
            return "SHOULD ACT";
        }else {
            return "SHOULD STOP";
        }
        //if-else
    }
    //evalActing

    action setAction(int num_action) {

        if(not(self.isOperational())) {return;}

        self.attrs["ACT_COMMAND"] <- num_action;

        if(num_action = ckeytonumber["HIGH"]) {
            self.acting <- true;
            //write "I'm actuator "+self.id+" and I'm ACTING"; //comentar cuando haya gráficos, esto se reemplaza con el aspect default
        }else if(num_action = ckeytonumber["LOW"]) {
            self.acting <- false;
            //write "I'm actuator "+self.id+" and I'm NOT ACTING"; //comentar cuando haya gráficos, esto se reemplaza con el aspect default
        }
        //if-else

        return;
    }
    //setAction

    //funciones para gráficos--------------------------------------------

    aspect default {

        if(self.parent = ckeytonumber["DEFAULT"]) {
            //no despliegues un satellite sin padre
            do resetLocation();
        }else if(not(self.isOperational())) {
        	draw (self.idstring) color:#black;
            draw actuator_disabled size:icon_size;
        }else if(self.acting) {
        	draw (self.idstring) color:#black;
            draw actuator_on size:icon_size;
        }else {
        	draw (self.idstring) color:#black;
            draw actuator_off size:icon_size;
        }
        //if-else

        draw polyline([self.location, self.getParentLocation()]) color:#black begin_arrow:1;
    }
    //aspect default
}
//species Actuator

experiment "Request_Response" type:gui {

    parameter "01 - Device Type [1:S, 2:A, 3:CN]" category:"Create New Device"                                    var:createDevice_tipo              on_change:{};
    parameter "02 - Sensor/Actuator ID"           category:"Replace Sensor/Actuator"                              var:replaceDevice_sa_id            on_change:{};
    parameter "03 - Sensor/Actuator ID"           category:"Delete Sensor/Actuator"                               var:destroySatellite_sa_id         on_change:{};
    parameter "04 - Compute Node ID"              category:"Delete Compute Node And Its Linked Sensors/Actuators" var:destroyComputeNode_cn_id       on_change:{};
    parameter "05 - Sensor/Actuator ID"           category:"Unlink Sensor/Actuator From Compute Node"             var:unlinkSubDevice_sa_id          on_change:{};
    parameter "06 - Sensor/Actuator ID"           category:"Link Sensor/Actuator To Compute Node"                 var:linkDeviceToComputeNode_sa_id  on_change:{};
    parameter "07 - Compute Node ID"              category:"Link Sensor/Actuator To Compute Node"                 var:linkDeviceToComputeNode_new_cn on_change:{};
    parameter "08 - Device ID"                    category:"Reset Device To Default"                              var:applyDefaultConfig_device_id   on_change:{};
    parameter "10 - Device ID"                    category:"Set Device Public Key"                                var:setPublicKey_device_id         on_change:{};
    parameter "11 - Public Key"                   category:"Set Device Public Key"                                var:setPublicKey_config_value      on_change:{};
    parameter "12 - Compute Node ID"              category:"Set Compute Node Threshold"                           var:setThreshold_cn_id             on_change:{};
    parameter "13 - Threshold"                    category:"Set Compute Node Threshold"                           var:setThreshold_config_value      on_change:{};
    parameter "14 - Device ID"                    category:"Grant Permissions To Device"                          var:grantPerms_device_id           on_change:{};
    parameter "15 - Device ID"                    category:"Deny Permissions To Device"                           var:denyPerms_device_id            on_change:{};
    parameter "16 - Device ID"                    category:"Turn Device On"                                       var:turnOnDevice_device_id         on_change:{};
    parameter "17 - Device ID"                    category:"Turn Device Off"                                      var:turnOffDevice_device_id        on_change:{};

    user_command "18 - EXECUTE" category:"Ping Back-End"                                        color:#darkblue {ask world {do PingBackEndHandler;}}
    user_command "19 - EXECUTE" category:"Create New Device"                                    color:#darkred  {ask world {do CreateNewDeviceHandler;}}
    user_command "20 - EXECUTE" category:"Replace Sensor/Actuator"                              color:#darkred  {ask world {do ReplaceSatelliteHandler;}}
    user_command "21 - EXECUTE" category:"Delete Sensor/Actuator"                               color:#darkred  {ask world {do DeleteSatelliteHandler;}}
    user_command "22 - EXECUTE" category:"Delete Compute Node And Its Linked Sensors/Actuators" color:#darkred  {ask world {do DeleteCNHandler;}}
    user_command "23 - EXECUTE" category:"Reset System To Default"                              color:#darkred  {ask world {do ResetSystemHandler;}}
    user_command "24 - EXECUTE" category:"Unlink Sensor/Actuator From Compute Node"             color:#darkred  {ask world {do UnlinkSatelliteHandler;}}
    user_command "25 - EXECUTE" category:"Link Sensor/Actuator To Compute Node"                 color:#darkred  {ask world {do LinkSatelliteHandler;}}
    user_command "26 - EXECUTE" category:"Reset Device To Default"                              color:#darkred  {ask world {do ResetDeviceHandler;}}
    user_command "27 - EXECUTE" category:"Set Device Public Key"                                color:#darkred  {ask world {do SetPublicKeyHandler;}}
    user_command "28 - EXECUTE" category:"Set Compute Node Threshold"                           color:#darkred  {ask world {do SetThresholdHandler;}}
    user_command "29 - EXECUTE" category:"Grant Permissions To Device"                          color:#darkred  {ask world {do GrantPermissionsHandler;}}
    user_command "30 - EXECUTE" category:"Deny Permissions To Device"                           color:#darkred  {ask world {do DenyPermissionsHandler;}}
    user_command "31 - EXECUTE" category:"Turn Device On"                                       color:#darkred  {ask world {do TurnDeviceOnHandler;}}
    user_command "32 - EXECUTE" category:"Turn Device Off"                                      color:#darkred  {ask world {do TurnDeviceOffHandler;}}
    user_command "33 - EXECUTE" category:"Turn All Devices On"                                  color:#darkred  {ask world {do TurnEverythingOnHandler;}}
    user_command "34 - EXECUTE" category:"Turn All Devices Off"                                 color:#darkred  {ask world {do TurnEverythingOffHandler;}}
    user_command "35 - EXECUTE" category:"Toggle Moving Lights"                                 color:#black    {ask AmbientLight {do toggleMovement();}}

    output {
        display myDisplay background:#lightgrey {
            species AmbientLight     aspect:default;
            species ComputeNode      aspect:default;
            species Sensor           aspect:default;
            species Actuator         aspect:default;
            species BorderLine       aspect:default;
            //species SummaryContainer aspect:default;
        }
        //myDisplay
    }
    //output
}
//experiment Request_Response

//eof

