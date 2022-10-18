/**
* Name: TesisTest
* Based on the internal empty template.
* Author: enorma
* Tags: lolazo
*/
//

/**cosas urgentes que faltan:
	*métele algo de lógica para "sospechar" que un dispositivo ha sido censurado o hackeado
	*esa lógica debe togglear la variable compromised entre true y false
	*por lo pronto basta con un botón en la GUI de "simular hack" o algo...

	*coordenadas en el escenario:
	{  0.0 ,   0.0}; //top left
	{  0.0 , 100.0}; //bottom left
	{100.0 ,   0.0}; //top right
	{100.0 , 100.0}; //top left
*/
//

model TesisTest

global torus:false {

	int computenodes_min       <- 1;
	int computenodes_max       <- 2; //ponle 1 para debuggear, 5 para producción

	int sensors_per_cm_min     <- 1;
	int sensors_per_cm_max     <- 3; //ponle 2 o 3 para debuggear, 5 para producción

	int actuators_per_cm_min   <- 1;
	int actuators_per_cm_max   <- 3; //ponle 1 para debuggear, 5 para producción

	float satellite_radius_min <- 1.0;
	float satellite_radius_max <- 10.0;
	float satellite_proximity  <- 5.0;
	float cm_proximity         <- 20.0;

	int   spotlights           <- 3; //ponle 2 o 3 para debuggear...
	float spotlight_radius     <- 10.0;

	file actuator_disabled     <- image_file("../includes/data/bulb_disabled.png");
	file actuator_off          <- image_file("../includes/data/bulb_off.png");
	file actuator_on           <- image_file("../includes/data/bulb_on.png");
	file compute_node          <- image_file("../includes/data/compute_node.png");
	file compute_node_disabled <- image_file("../includes/data/compute_node_disabled.png");
	file sensor_disabled       <- image_file("../includes/data/sensor_disabled.jpg");
	file sensor_off            <- image_file("../includes/data/sensor_off.jpg");
	file sensor_on             <- image_file("../includes/data/sensor_on.jpg");

	float icon_size <- 5.0;

	init {
		create ComputeNode  number:rnd(computenodes_min, computenodes_max);
		create AmbientLight number:spotlights;
	}
	//init
}

species AmbientLight skills:[moving] {

	init {
		self.speed <- 7.5;
	}
	//init

	reflex move {
		do wander amplitude:90.0;
	}
	//move

	aspect default {
		draw circle(spotlight_radius) color:#yellow;
	}
	//aspect default
}
//AmbientLight

species Device {

	bool compromised; //true si sospechamos que el sensor fué censurado o es malicioso
	bool allowed;     //true si el admin permite operar al sensor

	//ponerle un loop a las 2 funciones de abajo para
	//reasignar su ubicación si se traslapan con otro agente

	//colocar los nodos de cómputo a 20 unidades de cualquier borde
	//PROHIBIDO llamar esta función desde un sensor o actuador!!!
	action setCNLocation {

		bool keeplooping <- true;
		loop while:keeplooping {

			//definir una posición del dispositivo
			self.location <- {rnd(20.0, 80.0), rnd(20.0, 80.0)};

			//encontrar otros dispositivos cercanos
			list others <- (Device at_distance cm_proximity);
			others <- others + (ComputeNode at_distance cm_proximity);
			others <- others + (Sensor at_distance cm_proximity);
			others <- others + (Actuator at_distance cm_proximity);

			write "attempt to locate cn: " + self.name + " on location: " + self.location;
			write "found devices nearby: " + string(others);

			//si no hay dispositivos cercanos, confirmar la posición, si sí, reintentar
			if(empty(others)) {
				keeplooping <- false;
			}
			//if empty
		}
		//loop while:keeplooping

		write "attempt successful\n";
	}
	//setCNLocation

	//colocar los sensores y actuadores cerca de su nodo de cómputo
	//PROHIBIDO llamar esta función desde un ComputeNode!!!
	action setSatelliteLocation(point parentloc, string parentname) {

		float xrand;
		float yrand;
		bool keeplooping <- true;

		loop while:keeplooping {

			//definir una posición del dispositivo
			xrand <- ( rnd(satellite_radius_min, satellite_radius_max) * rnd(-1,1,2) );
			yrand <- ( rnd(satellite_radius_min, satellite_radius_max) * rnd(-1,1,2) );

			self.location <- parentloc + {xrand, yrand};

			//encontrar otros dispositivos cercanos
			list others <- (Device at_distance satellite_proximity);
			others <- others + (ComputeNode at_distance satellite_proximity);
			others <- others + (Sensor at_distance satellite_proximity);
			others <- others + (Actuator at_distance satellite_proximity);

			write "attempt to locate sat: " + self.name + " of cn: " + parentname + " on location: " + self.location;
			write "found devices nearby: " + string(others);

			//si no hay dispositivos cercanos, confirmar la posición, si sí, reintentar
			if(empty(others)) {
				keeplooping <- false;
			}
			//if empty
		}
		//loop while:keeplooping

		write "attempt successful\n";
	}
	//setSatelliteLocation

	//necesito lógica para togglear la variable compromised
	//debe ser true si sospecho que el dispositivo fué hackeado o censurado
	//y false si estoy segurísimo que el dispositivo es benigno
	//por ahorita basta con un botón en la GUI para togglear la variable
	//puedo usar el Device.name para identificar el dispositivo.
}
//Device

species Sensor parent:Device {

	ComputeNode nodopadre; //identifica al nodo de cómputo que lo controla

	int lightlevel; //cantidad de luz natural que percibe

	init {

		self.compromised <- false;
		self.allowed     <- true;
		self.lightlevel  <- 0;

		do setSatelliteLocation(self.nodopadre.location, self.nodopadre.name);
	}
	//init

	//detectar y cuantificar la luz ambiental detectada
	reflex getAmbientLight when:self.allowed {
		//checar si la luz natural le ilumina
		self.lightlevel <- empty(AmbientLight at_distance(spotlight_radius)) ? 0 : 10;
	}
	//getAmbientLight

	aspect default {

		int min_sunlight;

		ask nodopadre {
			min_sunlight <- self.threshold;
		}
		//nodopadre

		if(!self.allowed or self.compromised) {
			draw sensor_disabled size:icon_size;
			draw (self.name + " is banned") color:#black;
		}else if(self.lightlevel > min_sunlight) {
			draw sensor_on size:icon_size;
			draw (self.name + " sees light") color:#black;
		}else {
			draw sensor_off size:icon_size;
			draw (self.name + " sees dark") color:#black;
		}
		//if-else

		draw polyline([self.location, self.nodopadre.location]) color:#black end_arrow:1;
	}
	//aspect default
}
//Sensor

species Actuator parent:Device {

	ComputeNode nodopadre; //identifica al nodo de cómputo que lo controla

	bool lights_needed;    //indica si debería estar encendida la luz artificial
	bool lights_status;    //indica si la luz está encendida o apagada

	init {
		self.compromised   <- false;
		self.allowed       <- true;
		self.lights_needed <- false;
		self.lights_status <- false;

		do setSatelliteLocation(self.nodopadre.location, self.nodopadre.name);
	}
	//init

	//responder a la necesidad de apagar o prender la luz
	reflex toggleLight when:self.allowed {
		//encender o apagar la luz artificial según se necesite
		self.lights_status <- self.lights_needed;
	}
	//toggleLight

	aspect default {

		if(!self.allowed or self.compromised) {
			draw actuator_disabled size:icon_size;
			draw (self.name + " is banned") color:#black;
		}else if(self.lights_status) {
			draw actuator_on size:icon_size;
			draw (self.name + " lights on") color:#black;
		}else {
			draw actuator_off size:icon_size;
			draw (self.name + " lights off") color:#black;
		}
		//if-else

		draw polyline([self.location, self.nodopadre.location]) color:#black begin_arrow:1;
	}
	//aspect default
}
//Actuator

species ComputeNode parent:Device {

	int  how_many_sensors;     //cuántos sensores tendrá
	int  how_many_actuators;   //cuántos actuadores tendrá
	int  threshold;            //cuál es el umbral de luz ambiental para necesitar luz artificial
	bool need_light;           //si debemos prender la luz artificial o no

	list<Sensor>   sensores;   //lista de sensores conectados al nodo
	list<Actuator> actuadores; //lista de actuadores conectados al nodo

	init {

		//el nodo es inicializado con permisos
		self.compromised        <- false;
		self.allowed            <- true;

		//definir cuántos sensores y actuadores habrá (se decide al azar pero el min y max son configurables)
		self.how_many_sensors   <- rnd(sensors_per_cm_min,   sensors_per_cm_max);
		self.how_many_actuators <- rnd(actuators_per_cm_min, actuators_per_cm_max);

		//estas variables son exclusivas del caso de uso (sistema de alumbrado)
		self.threshold          <- 5; //threshold debe definirse en la blockchain, se declara aquí temporalmente para debuggear
		self.need_light         <- false;

		do setCNLocation;

		//crear a sus sensores y actuadores
		create Sensor   number:self.how_many_sensors   with:[nodopadre::self];
		create Actuator number:self.how_many_actuators with:[nodopadre::self];

		//agregar a sus sensores a una lista
		ask Sensor {
			if(self.nodopadre = myself) {
				add self to:myself.sensores;
			}
			//if
		}
		//ask Sensor

		//agregar a sus actuadores a una lista
		ask Actuator {
			if(self.nodopadre = myself) {
				add self to:myself.actuadores;
			}
			//if
		}
		//ask Actuator
	}
	//init

	bool getDevicePerms(Device d) {

		//la lógica de aquí abajo es temporal
		//quítala y pon un request a python para obtener los permisos cuando aquello jale
		//no importa si usa ETH o si es simulado en python
		//usa d.name para identificar al dispositivo

		return ( rnd(0.0, 1.0) < 2.0 ); //ponle menor a 0.8 para calar esto, ponle menor a 2.0 para desactivarlo
	}
	//getDevicePerms

	action getAllPerms {
		loop dev over:(self.sensores + self.actuadores) {
			ask dev {
				self.allowed <- myself.getDevicePerms(self);
			}
			//ask dev
		}
		//loop dev
	}
	//getAllPerms

	reflex pollForPerms {
		self.allowed <- self.getDevicePerms(self);
		if(self.allowed) {
			do getAllPerms;
		}
		//if
	}
	//pollForPerms

	//si el compute node está banneado, bannear también a todos sus sensores y actuadores
	reflex cascadeDisallowance when:!self.allowed {
		ask (self.sensores + self.actuadores) {
			self.allowed <- false;
		}
		//ask
	}
	//cascadeDisallowance

	reflex respondToLight when:self.allowed {

		self.need_light <- false;

		ask self.sensores {
			if(self.lightlevel < myself.threshold) {
				myself.need_light <- true;
			}
			//if
		}
		//ask

		ask self.actuadores {
			self.lights_needed <- myself.need_light;
		}
		//ask
	}
	//respondToLight

	aspect default {

		if(!self.allowed or self.compromised) {
			draw compute_node_disabled size:icon_size;
			draw (self.name + " is banned") color:#black;
		}else {
			draw compute_node size:icon_size;
			draw (self.name + " is working") color:#black;
		}
		//if-else
	}
	//aspect default
}
//ComputeNode

experiment StartSimulation type:gui {

	output {
		display myDisplay {
			species AmbientLight aspect:default;
			species ComputeNode aspect:default;
			species Sensor aspect:default;
			species Actuator aspect:default;
		}
		//myDisplay
	}
	//output
}
//StartSimulation

//eof
