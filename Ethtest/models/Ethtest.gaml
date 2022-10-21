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

		geometry shape <- rectangle({120, 100});

        string prefix_client <- "Client_"; //todos los clientes tendrán el prefijo "Client_"

        int simulation_id    <- 0;
        int cyclestoloop     <- 10; //ponlo en la velocidad más lenta!
        int counterdown      <- cyclestoloop;
        int refreshcounter   <- 0;
        int devicelimit      <- 14;
        int cn_limit         <- 9;
        int satellitelimit   <- 8;
        int orphanlimit      <- 5;
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
        point default_place <- {120,5};

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

		map<point,bool> orphan_sat_places <- [
			{110,20} :: false,
			{110,35} :: false,
			{110,50} :: false,
			{110,65} :: false,
			{110,80} :: false
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

		action refreshSatellitePlace(int satid, string sattype, int new_cn) {

			//refrescar su posición ahorita que conocemos su padre anterior y actual

			switch sattype {

				match "SENSOR" {
					ask Sensor where(each.id=satid) {

						if( (new_cn = ckeytonumber["DEFAULT"]) and (self.location = default_place) ) { //es stray en lugar default
							do setStraySatLocation();
						}else if( (new_cn = ckeytonumber["DEFAULT"]) and (self.location.x < 100.0) ) { //es stray
							do freeUpSatPlace();
							do setStraySatLocation();
						}else if( (new_cn > ckeytonumber["DEFAULT"]) and (self.location.x > 100.0) ) { //tiene padre
							do freeUpStrayPlace();
							do setFutureSatLocation(new_cn);
						}
						//if-else
					}
					//ask Sensor

					break;
				}
				match "ACTUATOR" {
					ask Actuator where(each.id=satid) {

						if( (new_cn = ckeytonumber["DEFAULT"]) and (self.location = default_place) ) { //es stray en lugar default
							do setStraySatLocation();
						}else if( (new_cn = ckeytonumber["DEFAULT"]) and (self.location.x < 100.0) ) { //es stray
							do freeUpSatPlace();
							do setStraySatLocation();
						}else if( (new_cn > ckeytonumber["DEFAULT"]) and (self.location.x > 100.0) ) { //tiene padre
							do freeUpStrayPlace();
							do setFutureSatLocation(new_cn);
						}
						//if-else
					}
					//ask Actuator

					break;
				}
				//match
			}
			//switch

			return;
		}
		//refreshSatellitePlace

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
                if !computeNodeExists(d) {do createAgent(d, "COMPUTE_NODE");}
            }
            //loop over compute_nodes

            loop d over:devices["sensors"] {
                if !sensorExists(d) {do createAgent(d, "SENSOR");}
            }
            //loop over sensors

            loop d over:devices["actuators"] {
                if !actuatorExists(d) {do createAgent(d, "ACTUATOR");}
            }
            //loop over actuators

            //Device que exista en GAMA pero no en el ledger, se elimina.

            ask Sensor where not(each.id in devices["sensors"]) {
            	//los freeUps no hacen nada si les pides liberar un lugar que no conocen
            	do freeUpSatPlace(); //para eliminar un sat con CN
            	do freeUpStrayPlace(); //para eliminar un sat sin CN
            	do die;
            }
            //ask Sensor

            ask Actuator where not(each.id in devices["actuators"]) {
            	//los freeUps no hacen nada si les pides liberar un lugar que no conocen
            	do freeUpSatPlace(); //para eliminar un sat con CN
            	do freeUpStrayPlace(); //para eliminar un sat sin CN
            	do die;
            }
            //ask Actuator

            ask ComputeNode where not(each.id in devices["compute_nodes"]) {
            	//los freeUps no hacen nada si les pides liberar un lugar que no conocen
            	do freeUpCNPlace();
            	do die;
            }
            //ask ComputeNode

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

                	do refreshSatellitePlace(device_id, "SENSOR", device_attributes["PARENT"]);

                    ask Sensor where(each.id=device_id) {
                        self.attrs <- device_attributes;
                        do refreshParent();
                    }
                    //ask

                    break;
                }
                match ckeytonumber["ACTUATOR"] {

                	do refreshSatellitePlace(device_id, "ACTUATOR", device_attributes["PARENT"]);

                    ask Actuator where(each.id=device_id) {
                        self.attrs <- device_attributes;
                        do refreshParent();
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
                //para poder foldear...
                do refreshSatLists(new_child_sensors, new_child_actuators);
            }
            //ask ComputeNode

			//actualizar las posiciones de los agentes en la simulación

			//ask Sensor      {do refreshLocation();}  //togglea la posición del sat entre los strays y alrededor de su CN
			//ask Actuator    {do refreshLocation();}  //togglea la posición del sat entre los strays y alrededor de su CN
			ask ComputeNode {do refreshSatPlaces();} //libera lugares recién desocupados

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

        bool hasParentCN(string satid) {

            if !validateSatelliteID(satid) {return false;}

			bool parentcn1 <- false;
			bool parentcn2 <- false;

			ask Sensor   where(each.id=int(satid)) {parentcn1 <- self.hasParent();}
			ask Actuator where(each.id=int(satid)) {parentcn2 <- self.hasParent();}

            if( !parentcn1 and !parentcn2 ) {return false;}

            return true;
        }
        //hasParentCN

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

		int countStraySats {

			int strays <- 0;

			ask Sensor {
				if !self.hasParent() {strays <- strays+1;}
			}
			//ask Sensor

			ask Actuator {
				if !self.hasParent() {strays <- strays+1;}
			}
			//ask Actuator

			return strays;
		}
		//countStraySats

		bool tooManyStraySats {
			if(countStraySats() >= orphanlimit) {return true;}
			return false;
		}
		//tooManyStraySats
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

            if !validateType(createDevice_tipo) { //que el tipo exista
                write "Input ERROR at CreateNewDevice: ["+createDevice_tipo+"] is not a valid type.";
                return;
            }
            //if validateType

            if deviceAmount() >= devicelimit { //que no hayan demasiados devices ya
                write "Input ERROR at CreateNewDevice: too many devices already created.";
                return;
            }
            //if deviceAmount

			if( (createDevice_tipo = "3") and (length(ComputeNode) >= cn_limit) ) { //que no hayan más de 9 CNs
				write "Input ERROR at CreateNewDevice: too many Compute Nodes already created.";
				return;
			}
			//if cn_limit

			if( (createDevice_tipo in ["1","2"]) and tooManyStraySats() ) { //que no hayan más de 5 satélites huérfanos
				write "Input ERROR at CreateNewDevice: too many unlinked Sensors/Actuators already created.";
				return;
			}
			//if tooManyStraySats

            do outgoingMessage("createDevice");
            return;
        }
        //CreateNewDeviceHandler

        action ReplaceSatelliteHandler {

            if !validateSatelliteID(replaceDevice_sa_id) { //que el satellite exista
                write "Input ERROR at ReplaceSatellite: Sensor/Actuator ["+replaceDevice_sa_id+"] not found.";
                return;
            }
            //if validateSatelliteID

            if !hasParentCN(replaceDevice_sa_id) { //que tenga padre
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

            if !validateSatelliteID(destroySatellite_sa_id) { //que el satellite exista
                write "Input ERROR at DeleteSatellite: Sensor/Actuator ["+destroySatellite_sa_id+"] not found.";
                return;
            }
            //if validateSatelliteID

            do outgoingMessage("destroySatellite");
            return;
        }
        //DeleteSatelliteHandler

        action DeleteCNHandler {

            if !validateCNID(destroyComputeNode_cn_id) { //que exista el CN
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

            if !validateSatelliteID(unlinkSubDevice_sa_id) { //que el satellite exista
                write "Input ERROR at UnlinkSatellite: Sensor/Actuator ["+unlinkSubDevice_sa_id+"] not found.";
                return;
            }
            //if validateSatelliteID

            if !hasParentCN(unlinkSubDevice_sa_id) { //que tenga padre
                write "Input ERROR at UnlinkSatellite: Sensor/Actuator ["+unlinkSubDevice_sa_id+"] has no Compute Node.";
                return;
            }
            //if hasParent

			if tooManyStraySats() { //que no hayan más de 5 satélites huérfanos
				write "Input ERROR at UnlinkSatellite: not enough space for another unlinked Sensor/Actuator.";
				return;
			}
			//if tooManyStraySats

            do outgoingMessage("unlinkSubDevice");
            return;
        }
        //UnlinkSatelliteHandler

        action LinkSatelliteHandler {

            if !validateSatelliteID(linkDeviceToComputeNode_sa_id) { //que el sat exista
                write "Input ERROR at LinkSatellite: Sensor/Actuator ["+linkDeviceToComputeNode_sa_id+"] not found.";
                return;
            }
            //if validateSatelliteID

            if !validateCNID(linkDeviceToComputeNode_new_cn) { //que el cn exista
                write "Input ERROR at LinkSatellite: Compute Node ["+linkDeviceToComputeNode_new_cn+"] not found.";
                return;
            }
            //if validateCNID

            if hasParentCN(linkDeviceToComputeNode_sa_id) { //que no tenga padre
                write "Input ERROR at LinkSatellite: Sensor/Actuator ["+linkDeviceToComputeNode_sa_id+"] already has a Compute Node.";
                return;
            }
            //if hasParent

            if !canHaveChildren(linkDeviceToComputeNode_new_cn) { //que el cn no tenga demasiados hijos
                write "Input ERROR at LinkSatellite: Compute Node ["+linkDeviceToComputeNode_new_cn+"] can't have any more linked devices.";
                return;
            }
            //if canHaveChildren

            do outgoingMessage("linkDeviceToComputeNode");
            return;
        }
        //LinkSatelliteHandler

        action ResetDeviceHandler {

            if !validateDeviceID(applyDefaultConfig_device_id) { //que el device exista
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

            if !validateDeviceID(setPublicKey_device_id) { //que el device exista
                write "Input ERROR at SetPublicKey: Device ["+setPublicKey_device_id+"] not found.";
                return;
            }
            //if validateDeviceID

            if !validatePublicKey(setPublicKey_config_value) { //que la llave esté dentro del rango
                write "Input ERROR at SetPublicKey: Public key ["+setPublicKey_config_value+"] out of range [1000,9999].";
                return;
            }
            //if validatePublicKey

            do outgoingMessage("setPublicKey");
            return;
        }
        //SetPublicKeyHandler

        action SetThresholdHandler {

            if !validateCNID(setThreshold_cn_id) { //que el cn exista
                write "Input ERROR at SetThreshold: Compute Node ["+setThreshold_cn_id+"] not found.";
                return;
            }
            //if validateDeviceID

            if !validateThreshold(setThreshold_config_value) { //que el threshold esté dentro del rango
                write "Input ERROR at SetThreshold: Threshold ["+setThreshold_config_value+"] out of range ["+th_low_bound+","+th_high_bound+"].";
                return;
            }
            //if validateThreshold

            do outgoingMessage("setThreshold");
            return;
        }
        //SetThresholdHandler

        action GrantPermissionsHandler {

            if !validateDeviceID(grantPerms_device_id) { //que el device exista
                write "Input ERROR at GrantPermissions: Device ["+grantPerms_device_id+"] not found.";
                return;
            }
            //if validateDeviceID

            if !parentIsAble(int(grantPerms_device_id)) { //que el CN padre esté habilitado
                write "Input ERROR at GrantPermissions: Device ["+grantPerms_device_id+"]'s Compute Node is not operational.";
                return;
            }
            //if parentIsAble

            do outgoingMessage("grantPerms");
            return;
        }
        //GrantPermissionsHandler

        action DenyPermissionsHandler {

            if !validateDeviceID(denyPerms_device_id) { //que el device exista
                write "Input ERROR at DenyPermissions: Device ["+denyPerms_device_id+"] not found.";
                return;
            }
            //if validateDeviceID

            do outgoingMessage("denyPerms");
            return;
        }
        //DenyPermissionsHandler

        action TurnDeviceOnHandler {

            if !validateDeviceID(turnOnDevice_device_id) { //que el device exista
                write "Input ERROR at TurnDeviceOn: Device ["+turnOnDevice_device_id+"] not found.";
                return;
            }
            //if validateDeviceID

            if !parentIsAble(int(turnOnDevice_device_id)) { //que el CN padre esté habilitado
                write "Input ERROR at TurnDeviceOn: Device ["+turnOnDevice_device_id+"]'s Compute Node is not operational.";
                return;
            }
            //if parentIsAble

            do outgoingMessage("turnOnDevice");
            return;
        }
        //TurnDeviceOnHandler

        action TurnDeviceOffHandler {

            if !validateDeviceID(turnOffDevice_device_id) { //que el device exista
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
                        if self.willEvalReadings() {cns_will_eval <- cns_will_eval+1;}
                    }
                    //ask Computenode

                    if( (cns_will_log = 0) and (cns_will_eval = 0) ) {
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
                    if cns_will_log > 0 {
                        ask ComputeNode {do logReadings;} //aquí se llama a uploadReading N veces (una por cada Sensor)
                        write "";
                    }
                    //if cns_will_log

                    //comandar a los actuadores según las lecturas
                    if cns_will_eval > 0 {
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
                    if( (cns_will_log = 0) and (cns_will_eval = 0) ) {
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
                    if cns_will_eval = 0 {
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

        	counterdown <- (cycle mod cyclestoloop);
        	
            if( showcounter and counterdown=0 ) {
            	write ""+(counterdown)+"...";
            }else if showcounter {
            	write ""+(cyclestoloop - counterdown)+"...";
            }
            //if-else

            return;
        }
        //reflex countDownCycles

        //si quieres detener el loop principal cambia el when de arriba por: when:false
        reflex stateRefresher when:every(cyclestoloop#cycle) {

            //sólo pasa de aquí si ya se recibió y procesó el response a todos los requests anteriores
            if !got_response {
            	write "UDP Responses pending. Skipping refresh cycle...";
            	return; //si seguimos esperando algún response, nos brincamos este ciclo de refresh
            }
            //if

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

			//write "I just got: ["+string(s.contents)+"]"; //descomentar para debuggear

			if("!!" in string(s.contents)) { //el mensaje aún no termina, necesitas el siguiente pedazo

				//remover caracteres basura a la derecha y appendar al buffer
				ask world {myself.msg <- removeRemainder(string(s.contents));}
				self.buffer <- (self.buffer + self.msg);
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

		draw polyline([{  0.1 ,  0.1} , {119.9 ,  0.1}]) color:#black end_arrow:0; //top horizontal
		draw polyline([{  0.1 , 99.9} , {119.9 , 99.9}]) color:#black end_arrow:0; //bottom horizontal
        draw polyline([{  0.1 ,  0.1} , {  0.1 , 99.9}]) color:#black end_arrow:0; //left vertical
        draw polyline([{ 99.9 ,  0.1} , { 99.9 , 99.9}]) color:#black end_arrow:0; //middle vertical
        draw polyline([{119.9 ,  0.1} , {119.9 , 99.9}]) color:#black end_arrow:0; //right vertical
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

    	if( (self.location.x + spotlight_radius) >= 100.0 ) {
    		self.location <- { (self.location.x-5) , self.location.y }; //está topando con la derecha
    	}else if( (self.location.x - spotlight_radius) <= 0.0 ) {
    		self.location <- { (self.location.x+5) , self.location.y }; //está topando con la izquierda
    	}else if( (self.location.y + spotlight_radius) >= 100.0 ) {
    		self.location <- { self.location.x , (self.location.y-5) }; //está topando abajo
    	}else if( (self.location.y - spotlight_radius) <= 0.0 ) {
    		self.location <- { self.location.x , (self.location.y+5) }; //está topando arriba
    	}else {
    		do wander amplitude:90.0 speed:self.speed;
    	}
    	//if-else

    	return;
    }
    //move

	action toggleMovement {
		self.moving <- !self.moving;
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
		self.location <- default_place;
		self.idstring <- "--- "+self.id;
	}
	//init

	//estas funciones están sólo para overridearlas en las species hijos
	action showUp {return;}
    bool isOperational {return false;}
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
        if (self.attrs["THRESHOLD"]     = ckeytonumber["DEFAULT"]) {return false;} //false if threshold isn't set
        if (self.attrs["PERMISSION"]    < ckeytonumber["HIGH"])    {return false;} //false without permission
        if (self.attrs["ON_OFF_STATUS"] < ckeytonumber["HIGH"])    {return false;} //false while off

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
        if !self.isOperational() {return;} //no hacer nada si el CN no está habilitado
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

        if !self.isOperational() {return countreadings;} //no hacer nada si el CN no está habilitado

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

        if !self.isOperational()       {return false;} //no hacer nada si el CN no está habilitado
        if empty(self.child_actuators) {return false;} //no hacer nada si el CN no tiene actuadores

        return true;
    }
    //willEvalReadings

    action evalReadings {

        if !self.willEvalReadings() {return;}

        string msg_to_send <- "evalSensors/"+self.id;
        string waitstr <- "ESPERANDO (6) en ComputeNode/evalReadings al response del último ComputeNode/uploadReading...";
        ask world {do pickTCPAndSend(msg_to_send, waitstr);}
        return;
    }
    //evalReadings

    action commandActuators(int new_command) {

        //no hacer nada si el CN no está habilitado
        if !self.isOperational() {return;}

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

        loop while:istaken {
	        chosenidx   <- rnd( 0 , (cn_limit-1) );
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
		//satplaces
	}
	//setSatPlaces

	//colocar los sensores y actuadores cerca de su nodo de cómputo
	action setSatLocationInternal(int satid, string sattype) {

        bool  istaken <- true;
        int   chosenidx;
        point chosenpoint;

        loop while:istaken {
            chosenidx   <- rnd( 0 , (satellitelimit-1) );
            chosenpoint <- self.satplaces.keys[chosenidx];
            istaken     <- self.satplaces[chosenpoint];
        }
        //loop

		if(sattype="SENSOR") {
			ask Sensor   where(each.id=satid) {self.location <- chosenpoint;}
		}else if(sattype="ACTUATOR") {
			ask Actuator where(each.id=satid) {self.location <- chosenpoint;}
		}
		//if-else

		self.satplaces[chosenpoint] <- true;

		return;
	}
	//setSatLocationInternal

	action freeUpCNPlace {

		loop i over:self.satplaces.keys {
			self.satplaces[i] <- false;
		}
		//loop

		if( (self.location in places.keys) and (places[self.location] = true) ) {
			places[self.location] <- false;
		}
		//if

		return;
	}
	//freeUpCNPlace

	action freeUpSatPlaceInternal(point loc) {

		if( (loc in self.satplaces.keys) and (self.satplaces[loc] = true) ) {
			self.satplaces[loc] <- false;
		}
		//if

		return;
	}
	//freeUpSatPlaceInternal

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

		//POSSIBLE STATUSES:
		//off
		//no perms
		//default threshold
		//working

		draw (self.idstring) color:#black;

		if(self.attrs["ON_OFF_STATUS"] = ckeytonumber["LOW"]) { //off
			draw compute_node_disabled size:icon_size;
		}else if(self.attrs["PERMISSION"] = ckeytonumber["LOW"]) { //no perms
			draw compute_node_disabled size:icon_size;
		}else if(self.attrs["THRESHOLD"] = ckeytonumber["DEFAULT"]) { //default threshold
			draw compute_node_disabled size:icon_size;
		}else { //working
			draw compute_node size:icon_size;
		}
		//if-else

		loop loc over:self.satplaces.keys {
			if(self.satplaces[loc]) {
				draw polyline([self.location, loc]) color:#black end_arrow:0;
			}
		}
		//loop
    }
    //aspect default
}
//species ComputeNode

species Satellite parent:Device {

    int parent;

    init {
        self.attrs["PARENT"] <- ckeytonumber["DEFAULT"];
        parent               <- ckeytonumber["DEFAULT"];
    }
    //init

	bool hasParent {
		if(self.attrs["PARENT"] = ckeytonumber["DEFAULT"]) {return false;}
		return true;
	}
	//hasParent

    action refreshParent {
        //para poder foldear...
        self.parent <- self.attrs["PARENT"];
    }
    //refreshParent

    int getParentThreshold {

        if !self.hasParent() {
        	return ckeytonumber["DEFAULT"];
        }
        //if

        int th;
        ask ComputeNode where(each.id=self.attrs["PARENT"]) {
            th <- self.attrs["THRESHOLD"];
        }
        //ask ComputeNode

        return th;
    }
    //getParentThreshold

    bool parentIsOperational {

        if !self.hasParent() {return false;}

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
        if !self.hasParent()                                  {return false;} //false without a parent
        if !self.parentIsOperational()                        {return false;} //false if parent is unable
        if self.attrs["PERMISSION"]    < ckeytonumber["HIGH"] {return false;} //false without permission
        if self.attrs["ON_OFF_STATUS"] < ckeytonumber["HIGH"] {return false;} //false while off

        return true;
    }
    //isOperational

    //funciones para gráficos--------------------------------------------

    //colocar los sensores y actuadores cerca de su nodo de cómputo
    action setSatLocation {

		ask ComputeNode where(each.id=self.parent) {
			do setSatLocationInternal(myself.id, myself.type);
		}
		//ask

		return;
    }
    //setSatLocation

	action setFutureSatLocation(int cn_id) {

		ask ComputeNode where(each.id=cn_id) {
			do setSatLocationInternal(myself.id, myself.type);
		}
		//ask

		return;
	}
	//setFutureSatLocation

	action setStraySatLocation {

	    bool  istaken <- true;
	    int   chosenidx;
	    point chosenpoint;

        loop while:istaken {
	        chosenidx   <- rnd( 0 , (orphanlimit-1) );
	        chosenpoint <- orphan_sat_places.keys[chosenidx];
	        istaken     <- orphan_sat_places[chosenpoint];
        }
        //loop

		self.location <- chosenpoint;
		orphan_sat_places[chosenpoint] <- true;

        return;
	}
	//setStraySatLocation

	action freeUpSatPlace {

		//freeUpSatPlaceInternal no hace nada si le pides liberar un lugar que no conoce

		ask ComputeNode where(each.id=self.parent) {
			do freeUpSatPlaceInternal(myself.location);
		}
		//ask

		return;
	}
	//freeUpSatPlace

	action freeUpStrayPlace { //para tomar un stray sat y eliminarlo o asignarle un CN

		//se usa en refreshDevices para eliminar un stray sat
		//se usa en refreshSatellites/refreshLocation para poner a un sat que recién dejó de ser stray alrededor de su CN y quitarlo de los strays

		//no hacer nada si self.location no está entre las opciones
		if( (self.location in orphan_sat_places.keys) and (orphan_sat_places[self.location] = true) ) {
			orphan_sat_places[self.location] <- false;
		}
		//if

		return;
	}
	//freeUpStrayPlace

    point getParentLocation {

    	if !self.hasParent() {return;}

        point p_loc;
        ask ComputeNode where(each.id=self.parent) {
            p_loc <- self.location;
        }
        //ask
        return p_loc;
    }
    //getParentLocation
}
//species Satellite

species Sensor parent:Satellite {

    int reading;      //este se actualiza siempre, basado en la simulación (es el que enviamos al ledger)
    bool prev_aspect; //este es nomás para conservar el valor anterior, por si el aspect tuviera que seguir igual a como ya está

    init {
        self.reading               <- ckeytonumber["DEFAULT"];
        self.prev_aspect           <- false;
        self.attrs["LAST_READING"] <- ckeytonumber["DEFAULT"]; //este sólo guarda el valor sacado del ledger (es el que ilustramos en la simulación)
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

        if !self.isOperational() {
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

		//POSSIBLE STATUSES:
		//no parent
		//off
		//parent not working
		//no perms
		//sensing default (0)
		//sensing matches threshold
		//sensing dark
		//sensing light

        int p_th <- getParentThreshold();
		draw (self.idstring) color:#black;

		if !self.hasParent() { //no parent
			self.prev_aspect <- false;
			draw sensor_disabled size:icon_size;
		}else if self.attrs["ON_OFF_STATUS"] = ckeytonumber["LOW"] { //off
			self.prev_aspect <- false;
			draw sensor_disabled size:icon_size;
		}else if !self.parentIsOperational() { //parent not working
			self.prev_aspect <- false;
			draw sensor_disabled size:icon_size;
		}else if self.attrs["PERMISSION"] = ckeytonumber["LOW"] { //no perms
			self.prev_aspect <- false;
			draw sensor_disabled size:icon_size;
		}else if self.attrs["LAST_READING"] = ckeytonumber["DEFAULT"] { //sensing default
			self.prev_aspect <- false;
			draw sensor_disabled size:icon_size;
		}else if( (self.attrs["LAST_READING"] = p_th) and !self.prev_aspect ) { //sensing matches threshold, still be sensing dark
			self.prev_aspect <- false;
			draw sensor_off size:icon_size;
		}else if( (self.attrs["LAST_READING"] = p_th) and self.prev_aspect ) { //sensing matches threshold, still be sensing light
			self.prev_aspect <- true;
			draw sensor_on size:icon_size;
		}else if self.attrs["LAST_READING"] < p_th { //sensing dark
			self.prev_aspect <- false;
			draw sensor_off size:icon_size;
		}else { //sensing light
			self.prev_aspect <- true;
			draw sensor_on size:icon_size;
		}
		//if-else
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

        if !self.isOperational() {
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

        if !self.isOperational() {return;}

        self.attrs["ACT_COMMAND"] <- num_action;

        if(num_action = ckeytonumber["HIGH"]) {
            self.acting <- true;
        }else if(num_action = ckeytonumber["LOW"]) {
            self.acting <- false;
        }
        //if-else

        return;
    }
    //setAction

    //funciones para gráficos--------------------------------------------

    aspect default {

		//no parent
		//off
		//parent not working
		//no perms
		//lights off
		//lights on

		draw (self.idstring) color:#black;

		if !self.hasParent() { //no parent
			draw sensor_disabled size:icon_size;
		}else if self.attrs["ON_OFF_STATUS"] = ckeytonumber["LOW"] { //off
			draw sensor_disabled size:icon_size;
		}else if !self.parentIsOperational() { //parent not working
			draw sensor_disabled size:icon_size;
		}else if self.attrs["PERMISSION"] = ckeytonumber["LOW"] { //no perms
			draw sensor_disabled size:icon_size;
		}else if self.attrs["ACT_COMMAND"] = ckeytonumber["LOW"] { //lights off
			draw sensor_off size:icon_size;
		}else { //sensing light
			draw sensor_on size:icon_size;
		}
		//if-else
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

