/**
* Name: Sandbox
* Based on the internal empty template. 
* Author: enorma
* Tags: 
*/

model Sandbox

global {

	//declara las variables globales aquí
	list mylist <- [];
	map mymap <- map([]);
	string mystring <- "";
	int myint <- 0;
	int idseq <- 0;
	list<OneSpecies> targets <- [];
	list<OneSpecies> targets2 <- [];

	init {
		create OneSpecies number:10;
		//create AnotherSpecies number:4;
		//inicializa las variables globales aquí
		//write "Amount of Test Bed 1: "+length(OneSpecies);
		//write "Amount of Test Bed 2: "+length(AnotherSpecies);

		//mymap["somekey"] <- "somevalue";
		//mymap["anotherkey"] <- "anothervalue";

		targets <- (agents of_species OneSpecies);
		targets2 <- (targets where(each.testing));
		write "agents are: "+targets;
		write "testing agents are: "+targets2;

		ask targets {
			do writeStuff();
		}
		//do getMachineTime;
	}
	//init

	reflex testreturn {
		//do getMachineTime;
	}
}
//global

species OneSpecies {

	int id;
	bool testing;

	init {
		self.id      <- idseq;
		self.testing <- self.randomBool();
		idseq        <- idseq+1;
	}
	//init

	bool randomBool {
		bool rkey <- rnd_choice([true::0.5, false::0.5]);
		return rkey;
	}
	//randomBool

	action writeStuff {
		write "hola soy "+self+" con id "+self.id+" y estoy testeando: "+self.testing;
	}
	//writeStuff

	reflex retest when:every(10#cycle) {
		self.testing <- self.randomBool();
		int curcycle <- cycle;
		loop while:true {
			if(cycle = (curcycle + 5)) {
				break;
			}
		}
	}
	//retest
}
//OneSpecies

species AnotherSpecies {

	int id;

	action writeStuff {
		write "hola soy "+self+" de la especie 2 y mi id es "+self.id;
	}
}
//AnotherSpecies

experiment "Request_Response" type:gui {
	output {}
}
//experiment

//eof
