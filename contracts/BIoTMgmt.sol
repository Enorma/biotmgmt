// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.8.12 <0.9.0;

import "@openzeppelin/contracts/utils/Strings.sol";
//import "./BIoTStore.sol";

/**
 * @title BIoTMgmt
 * @dev BIoT management functions for my master's thesis's PoC.
 * @custom:dev-run-script ./scripts/deploy_with_ethers.ts
*/

//IMPORTANTE: Los requires están comentados sólo para que el tamaño sea
//menor al límite de 24576 bytes de spurious dragon.
//Entonces muchos wrappers que nomás meten requires se volvieron pointless
//y están todos comentados porque ni se van a usar...

/*ERROR CODES:
    DDE: device doesn't exist
    NCN: device is not compute node
    NSN: device is not sensor
    NAC: device is not actuator
    CDD: can't delete device
    NCH: device is not child of a CN
    HPA: device already has a parent CN
    SDF: new sensor doesn't fit
    ADF: new actuator doesn't fit
    DDF: new device doesn't fit
    NKD: no known devices
    KCN: key limit reached for CNs
    KSN: key limit reached for sensors
    KAC: key limit reached for actuators
    KST: key limit reached for satellites
    KDV: key limit reached for all
*/

//JAHALLA
contract BIoTMgmt {

    //---------------------------------------------------------------------------------------------------------------------------------------------
    //---CONSTANTES--------------------------------------------------------------------------------------------------------------------------------

    //-----------------------------------------------------------------
    //constantes auxiliares--------------------------------------------

    //tipos de dispositivos
    uint public constant SENSOR            = 1;
    uint public constant ACTUATOR          = 2;
    uint public constant COMPUTE_NODE      = 3;

    //estados de los actuadores y permisos
    uint public constant HIGH              = 11;
    uint public constant LOW               = 10; //no es cero para no confundirse con un valor default

    //valores default preestablecidos
    uint public constant DEFAULT_ID        = 0; //idéntico al ID de un dispositivo que no existe en devices y en ids
    uint public constant DEFAULT_VALUE     = 0; //idéntico al value de una key que no existe en un dispositivo

    //límites globales
    uint public constant DEVICE_AMOUNT_MAX = 15; //cantidad máxima de dispositivos soportada (15 para testear)
    uint public constant CONFIG_VARS_MAX   = 10; //cantidad máxima de key-value pairs de config soportada (10 para testear)

    //-----------------------------------------------------------------
    //constantes de config para los dispositivos-----------------------
    //son keys usadas en key-values, entonces--------------------------
    //¡NO deben haber dos con valores iguales!-------------------------

    //constantes para los compute nodes
    uint public constant AMOUNT_SENSORS   = 110; //cantidad de sensores asociados al CN
    uint public constant AMOUNT_ACTUATORS = 120; //cantidad de actuadores asociados al CN
    uint public constant THRESHOLD        = 130; //umbral para el valor reportado por sus sensores

    //constantes para los sensores
    uint public constant LAST_READING     = 210; //último valor reportado por el sensor

    //constantes para los actuadores
    uint public constant ACT_COMMAND      = 310; //indica si el actuador debe trabajar (11) o no (10)

    //constantes para los sensores y actuadores
    uint public constant PARENT           = 410; //id del CN al que está asociado

    //constantes para todos los dispositivos
    uint public constant ID               = 510; //id unívoco del dispositivo
    uint public constant TYPE             = 520; //tipo del dispositivo (S:1|A:2|CN:3)
    uint public constant PUBLIC_KEY       = 530; //llave pública del dispositivo
    uint public constant PERMISSION       = 540; //indica si el dispositivo tiene permiso de operar (11) o no (10)
    uint public constant ON_OFF_STATUS    = 550; //indica si el dispositivo está encendido (11) o apagado (10)

    //---------------------------------------------------------------------------------------------------------------------------------------------
    //---VARIABLES DE STORAGE----------------------------------------------------------------------------------------------------------------------

    //el ledger es un mapping de dispositivos y sus variables
    mapping(uint => mapping(uint => uint)) public devices;          //mapping del id de un dispositivo a su key-value de config
    mapping(uint => uint[DEVICE_AMOUNT_MAX-1]) public subsensors;   //mapping del id de un CN a su lista de sensores
    mapping(uint => uint[DEVICE_AMOUNT_MAX-1]) public subactuators; //mapping del id de un CN a su lista de actuadores

    //variables auxiliares en el ledger
    uint[CONFIG_VARS_MAX] public configkeys_cn;  //lista de keys en el key-value de config de los CN's
    uint[CONFIG_VARS_MAX] public configkeys_s;   //lista de keys en el key-value de config de los sensores
    uint[CONFIG_VARS_MAX] public configkeys_a;   //lista de keys en el key-value de config de los actuadores
    uint[CONFIG_VARS_MAX] public configkeys_sa;  //lista de keys en el key-value de config de los sensores y actuadores
    uint[CONFIG_VARS_MAX] public configkeys_all; //lista de keys en el key-value de config de todos los dispositivos
    uint public amount_keys_cn  = 0;             //cantidad de keys en el key-value de config de los CN's
    uint public amount_keys_s   = 0;             //cantidad de keys en el key-value de config de los sensores
    uint public amount_keys_a   = 0;             //cantidad de keys en el key-value de config de los actuadores
    uint public amount_keys_sa  = 0;             //cantidad de keys en el key-value de config de los sensores y actuadores
    uint public amount_keys_all = 0;             //cantidad de keys en el key-value de config de todos los dispositivos

    //variables auxiliares en el ledger
    uint[DEVICE_AMOUNT_MAX] public ids; //lista de ids de dispositivos conocidos (admite sólo 100, por ahora)
    uint public amount_devices = 0;     //cantidad de dispositivos conocidos
    uint public idseq = 0;              //ID del último dispositivo que se ha creado (cero si nunca se ha creado uno)
    bool public pingvalue = true;       //nomás para no mandar un true literal, y que la función pueda ser view para llamarla con call

    //---------------------------------------------------------------------------------------------------------------------------------------------
    //---CONSTRUCTOR-------------------------------------------------------------------------------------------------------------------------------

    //JAHALLA
    //lo único que necesita inicializarse son las keys conocidas de config
    constructor() {

        initKeyValueLists();

        //aquí puedes hardcodear cosas para testear...
        /*valores hardcodeados para testear:
            //----------------------------------------------
            //set 1

            ids[0] = 26;
            devices[26][ID] = 26;
            devices[26][TYPE] = COMPUTE_NODE;
            devices[26][PUBLIC_KEY] = 113634;
            devices[26][PERMISSION] = HIGH;
            devices[26][ON_OFF_STATUS] = HIGH;
            devices[26][AMOUNT_SENSORS] = 2;
            devices[26][AMOUNT_ACTUATORS] = 2;
            devices[26][THRESHOLD] = DEFAULT_VALUE;

            ids[1] = 12;
            devices[12][ID] = 12;
            devices[12][TYPE] = SENSOR;
            devices[12][PUBLIC_KEY] = 443853;
            devices[12][PERMISSION] = HIGH;
            devices[12][ON_OFF_STATUS] = HIGH;
            devices[12][PARENT] = 26;
            devices[12][LAST_READING] = DEFAULT_VALUE;

            ids[2] = 14;
            devices[14][ID] = 14;
            devices[14][TYPE] = SENSOR;
            devices[14][PUBLIC_KEY] = 859867;
            devices[14][PERMISSION] = HIGH;
            devices[14][ON_OFF_STATUS] = HIGH;
            devices[14][PARENT] = 26;
            devices[14][LAST_READING] = DEFAULT_VALUE;

            ids[3] = 16;
            devices[16][ID] = 16;
            devices[16][TYPE] = ACTUATOR;
            devices[16][PUBLIC_KEY] = 735896;
            devices[16][PERMISSION] = HIGH;
            devices[16][ON_OFF_STATUS] = HIGH;
            devices[16][PARENT] = 26;
            devices[16][ACT_COMMAND] = LOW;

            ids[4] = 69;
            devices[69][ID] = 69;
            devices[69][TYPE] = ACTUATOR;
            devices[69][PUBLIC_KEY] = 985953;
            devices[69][PERMISSION] = HIGH;
            devices[69][ON_OFF_STATUS] = HIGH;
            devices[69][PARENT] = 26;
            devices[69][ACT_COMMAND] = LOW;

            subsensors[26][0] = 12;
            subsensors[26][1] = 14;

            subactuators[26][0] = 16;
            subactuators[26][1] = 69;

            //----------------------------------------------
            //set 2

            ids[5] = 36;
            devices[36][ID] = 36;
            devices[36][TYPE] = COMPUTE_NODE;
            devices[36][PUBLIC_KEY] = 263273;
            devices[36][PERMISSION] = HIGH;
            devices[36][ON_OFF_STATUS] = HIGH;
            devices[36][AMOUNT_SENSORS] = 0; //2 para testear antes
            devices[36][AMOUNT_ACTUATORS] = 0; //2 para testear antes
            devices[36][THRESHOLD] = DEFAULT_VALUE;

            ids[6] = 49;
            devices[49][ID] = 49;
            devices[49][TYPE] = SENSOR;
            devices[49][PUBLIC_KEY] = 378537;
            devices[49][PERMISSION] = HIGH;
            devices[49][ON_OFF_STATUS] = HIGH;
            devices[49][PARENT] = 36;
            devices[49][LAST_READING] = DEFAULT_VALUE;

            ids[7] = 45;
            devices[45][ID] = 45;
            devices[45][TYPE] = SENSOR;
            devices[45][PUBLIC_KEY] = 563583;
            devices[45][PERMISSION] = HIGH;
            devices[45][ON_OFF_STATUS] = HIGH;
            devices[45][PARENT] = 36;
            devices[45][LAST_READING] = DEFAULT_VALUE;

            ids[8] = 78;
            devices[78][ID] = 78;
            devices[78][TYPE] = ACTUATOR;
            devices[78][PUBLIC_KEY] = 675893;
            devices[78][PERMISSION] = HIGH;
            devices[78][ON_OFF_STATUS] = HIGH;
            devices[78][PARENT] = 36;
            devices[78][ACT_COMMAND] = LOW;

            ids[9] = 76;
            devices[76][ID] = 76;
            devices[76][TYPE] = ACTUATOR;
            devices[76][PUBLIC_KEY] = 103983;
            devices[76][PERMISSION] = HIGH;
            devices[76][ON_OFF_STATUS] = HIGH;
            devices[76][PARENT] = 36;
            devices[76][ACT_COMMAND] = LOW;

            subsensors[36][0] = 49;
            subsensors[36][1] = 45;

            subactuators[36][0] = 78;
            subactuators[36][1] = 76;

            //----------------------------------------------
            //huérfanos

            ids[10] = 86;
            devices[86][ID] = 86;
            devices[86][TYPE] = SENSOR;
            devices[86][PUBLIC_KEY] = 200356;
            devices[86][PERMISSION] = HIGH;
            devices[86][ON_OFF_STATUS] = HIGH;
            devices[86][PARENT] = DEFAULT_ID;
            devices[86][LAST_READING] = DEFAULT_VALUE;

            ids[11] = 87;
            devices[87][ID] = 87;
            devices[87][TYPE] = SENSOR;
            devices[87][PUBLIC_KEY] = 200486;
            devices[87][PERMISSION] = HIGH;
            devices[87][ON_OFF_STATUS] = HIGH;
            devices[87][PARENT] = DEFAULT_ID;
            devices[87][LAST_READING] = DEFAULT_VALUE;

            ids[12] = 88;
            devices[88][ID] = 88;
            devices[88][TYPE] = ACTUATOR;
            devices[88][PUBLIC_KEY] = 200679;
            devices[88][PERMISSION] = HIGH;
            devices[88][ON_OFF_STATUS] = HIGH;
            devices[88][PARENT] = DEFAULT_ID;
            devices[88][ACT_COMMAND] = LOW;

            amount_devices = 6; //13 para testear antes
            idseq = 69;
        */
    }

    //JAHALLA
    //Inicializar la lista de variables de config conocidas para cada tipo de dispositivo
    function initKeyValueLists() public returns(bool success) {

        //constantes para los compute nodes
        delete configkeys_cn;
        configkeys_cn[0] = AMOUNT_SENSORS;
        configkeys_cn[1] = AMOUNT_ACTUATORS;
        configkeys_cn[2] = THRESHOLD;
        amount_keys_cn = 3;

        //constantes para los sensores
        delete configkeys_s;
        configkeys_s[0] = LAST_READING;
        amount_keys_s = 1;

        //constantes para los actuadores
        delete configkeys_a;
        configkeys_a[0] = ACT_COMMAND;
        amount_keys_a = 1;

        //constantes para los sensores y actuadores
        delete configkeys_sa;
        configkeys_sa[0] = PARENT;
        amount_keys_sa = 1;

        //constantes para todos los dispositivos
        delete configkeys_all;
        configkeys_all[0] = ID;
        configkeys_all[1] = TYPE;
        configkeys_all[2] = PUBLIC_KEY;
        configkeys_all[3] = PERMISSION;
        configkeys_all[4] = ON_OFF_STATUS;
        amount_keys_all = 5;

        return true;
    }

    //---------------------------------------------------------------------------------------------------------------------------------------------
    //---UTILITY FUNCTIONS FOR MODIFIERS-----------------------------------------------------------------------------------------------------------

    //-----------------------------------------------------------------
    //Encontrar un dispositivo y verificar que existe------------------

    //JAHALLA
    //Encontrar el índice de un ID en la lista de dispositivos (sólo funciona sobre el array zeroshifteado)
    function findIDInDeviceArray(uint target) public view returns(uint devindex) {

        for(uint i=0; i<amount_devices; i++) {
            if(target == ids[i]) {
                return i;
            }
        }

        //la función que llame a esta debe saber que
        //si se retorna el valor DEVICE_AMOUNT_MAX es que NO se encontró lo que buscaba
        return DEVICE_AMOUNT_MAX;
    }

    //---------------------------------------------------------------------------------------------------------------------------------------------
    //---CRUD OPERATIONS---------------------------------------------------------------------------------------------------------------------------

    //JAHALLA
    //TERMINAL - Crear / Editar parámetro de configuración de un dispositivo
    function writeDeviceVariable(uint id, uint key, uint value) public returns(bool success) {
        devices[id][key] = value;
        return true;
    }

    /*//WRAPPER de writeDeviceVariable - Crear / Editar parámetro de configuración de un dispositivo
        //JAHALLA
        function writeToDevice(uint id, uint key, uint value) public returns(bool success) {
            //require(deviceExists(id), "DDE01");
            writeDeviceVariable(id, key, value); //si pasa las validaciones, llega a la función wrappeada
            return true;
        }
    */

    //JAHALLA
    //TERMINAL - Leer parámetro de configuración de un dispositivo
    function readDeviceVariable(uint id, uint key) public view returns(uint configval) {
        //para poder foldear...
        return devices[id][key];
    }

    /*//WRAPPER de readDeviceVariable - Leer parámetro de configuración de un dispositivo
        //JAHALLA
        function readFromDevice(uint id, uint key) public view returns(uint configval) {
            //require(deviceExists(id), "DDE02");
            return readDeviceVariable(id, key); //si pasa las validaciones, llega a la función wrappeada
        }
    */

    //JAHALLA
    //TERMINAL - Eliminar parámetro de configuración de un dispositivo
    function deleteDeviceVariable(uint id, uint key) public returns(bool success) {
        delete devices[id][key];
        return true;
    }

    /*//WRAPPER de deleteDeviceVariable - Eliminar parámetro de configuración de un dispositivo
        //JAHALLA
        function deleteFromDevice(uint id, uint key) public returns(bool success) {
            //require(deviceExists(id), "DDE03");
            deleteDeviceVariable(id, key); //si pasa las validaciones, llega a la función wrappeada
            return true;
        }
    */

    //JAHALLA
    //Incrementar parámetro de configuración de un dispositivo
    function incrementDeviceVariable(uint id, uint key) public returns(bool success) {
        uint auxvar = readDeviceVariable(id, key);
        writeDeviceVariable(id, key, auxvar+1);
        return true;
    }

    //JAHALLA
    //Incrementar parámetro de configuración de un dispositivo
    function decrementDeviceVariable(uint id, uint key) public returns(bool success) {
        uint auxvar = readDeviceVariable(id, key);
        writeDeviceVariable(id, key, auxvar-1);
        return true;
    }

    //---------------------------------------------------------------------------------------------------------------------------------------------
    //---FUNCTIONS FOR VALIDATIONS--------------------------------------------------------------------------------------------------------------------

    //-----------------------------------------------------------------
    //verificar que los dispositivos existan y sean lo que dicen ser---

    //JAHALLA
    //CHECK, Verificar que el dispositivo en cuestión exista
    function deviceExists(uint id) public view returns(bool success) {
        //para poder foldear...
        return(findIDInDeviceArray(id) < DEVICE_AMOUNT_MAX);
    }

    //JAHALLA
    //CHECK, Verificar que el dispositivo en cuestión sea un Compute Node
    function isComputeNode(uint id) public view returns(bool success) {
        //para poder foldear...
        return(readDeviceVariable(id, TYPE) == COMPUTE_NODE);
    }

    //JAHALLA
    //CHECK, Verificar que el dispositivo en cuestión sea un Sensor
    function isSensor(uint id) public view returns(bool success) {
        //para poder foldear...
        return(readDeviceVariable(id, TYPE) == SENSOR);
    }

    //JAHALLA
    //CHECK, Verificar que el dispositivo en cuestión sea un Actuador
    function isActuator(uint id) public view returns(bool success) {
        //para poder foldear...
        return(readDeviceVariable(id, TYPE) == ACTUATOR);
    }

    //JAHALLA
    //CHECK, Verificar que el dispositivo en cuestión sea un Sensor o Actuador
    function isSensorOrActuator(uint id) public view returns(bool success) {
        uint tipo = readDeviceVariable(id, TYPE);
        return(tipo==SENSOR || tipo==ACTUATOR);
    }

    //CUANDO SE USE LA PRUEBO...
    /*//CHECK, Verificar que dos dispositivos sean ambos sensores o ambos actuadores (no se usa!)
        function bothAreSameSatellite(uint id1, uint id2) public view returns(bool success) { //(no se usa!)
            uint tipo1 = readDeviceVariable(id1, TYPE);
            uint tipo2 = readDeviceVariable(id2, TYPE);
            return( (tipo1==SENSOR && tipo2==SENSOR) || (tipo1==ACTUATOR && tipo2==ACTUATOR) );
        }
    */

    //JAHALLA
    //CHECK, Verificar que un sensor/actuador sea hijo de un compute node
    function isChildOfCN(uint cn_id, uint sa_id) public view returns(bool success) {
        //para poder foldear...
        return(readDeviceVariable(sa_id, PARENT) == cn_id);
    }

    //-----------------------------------------------------------------
    //verificar que haya espacio para agregar nuevos dispositivos------

    //JAHALLA
    //CHECK, Verificar que el límite de dispositivos conocidos no se haya alcanzado
    function newDeviceStillFits() public view returns(bool success) {
        //para poder foldear...
        return(amount_devices < DEVICE_AMOUNT_MAX);
    }

    //JAHALLA
    //CHECK, Verificar que el límite de sensores asociados a un determinado CN no se haya alcanzado
    function newSensorStillFitsCN(uint cn_id) public view returns(bool success) {
        //para poder foldear...
        return(readDeviceVariable(cn_id, AMOUNT_SENSORS) < DEVICE_AMOUNT_MAX-1);
    }

    //JAHALLA
    //CHECK, Verificar que el límite de actuadores asociados a un determinado CN no se haya alcanzado
    function newActuatorStillFitsCN(uint cn_id) public view returns(bool success) {
        //para poder foldear...
        return(readDeviceVariable(cn_id, AMOUNT_ACTUATORS) < DEVICE_AMOUNT_MAX-1);
    }

    //-----------------------------------------------------------------
    //verificar que sea posible eliminar o desasociar un dispositivo---

    //JAHALLA
    //CHECK, Verificar que existan dispositivos conocidos
    function knownDevicesExist() public view returns(bool success) {
        //para poder foldear...
        return(amount_devices > 0);
    }

    //JAHALLA
    //CHECK, Verificar que no se pretenda eliminar un índice mayor al máximo ni menor a cero
    function canDeleteDevice(uint index) public view returns(bool success) {
        //para poder foldear...
        return(index>=0 && index<amount_devices);
    }

    //CUANDO SE USE LA PRUEBO...
    /*//CHECK, Verificar que existan sensores que desasociar de un CN (no se usa!)
        function knownSubSensorsOfCNExist(uint cn_id) public view returns(bool success) { //(no se usa!)
            //para poder foldear...
            return(readDeviceVariable(cn_id, AMOUNT_SENSORS) > 0);
        }
    */

    //JAHALLA
    //CHECK, Verificar que no se pretenda desasociar un índice mayor al máximo ni menor a cero
    function canUnlinkSensor(uint cn_id, uint index) public view returns(bool success) {
        //para poder foldear...
        return(index>=0 && index<readDeviceVariable(cn_id, AMOUNT_SENSORS));
    }

    //CUANDO SE USE LA PRUEBO...
    /*//CHECK, Verificar que existan actuadores que desasociar de un CN (no se usa!)
        function knownSubActuatorsOfCNExist(uint cn_id) public view returns(bool success) { //(no se usa!)
            //para poder foldear...
            return(readDeviceVariable(cn_id, AMOUNT_ACTUATORS) > 0);
        }
    */

    //JAHALLA
    //CHECK, Verificar que no se pretenda desasociar un índice mayor al máximo ni menor a cero
    function canUnlinkActuator(uint cn_id, uint index) public view returns(bool success) {
        //para poder foldear...
        return(index>=0 && index<readDeviceVariable(cn_id, AMOUNT_ACTUATORS));
    }

    //JAHALLA
    //CHECK, Verificar que el dispositivo esté asociado a un CN
    function hasParent(uint id) public view returns(bool success) {
        //para poder foldear...
        return(readDeviceVariable(id, PARENT) > DEFAULT_ID);
    }

    //-----------------------------------------------------------------
    //verificar que los índices en los arreglos de IDs sean correctos--

    //CUANDO SE USE LA PRUEBO...
    /*//CHECK, Verificar que no manden índices fuera de rango para el arreglo de dispositivos (no se usa!)
        function isValidDeviceIndex(uint index) public view returns(bool success) { //(no se usa!)
            //para poder foldear...
            return(index >= 0 && index < DEVICE_AMOUNT_MAX);
        }
    */

    //CUANDO SE USE LA PRUEBO...
    /*//CHECK, Verificar que no manden índices fuera de rango para el arreglo de subsensores de un CN (no se usa!)
        function isValidSubSensorIndex(uint index) public view returns(bool success) { //(no se usa!)
            //para poder foldear...
            return(index >= 0 && index < DEVICE_AMOUNT_MAX-1);
        }
    */

    //CUANDO SE USE LA PRUEBO...
    /*//CHECK, Verificar que no manden índices fuera de rango para el arreglo de subactuadores de un CN (no se usa!)
        function isValidSubActuatorIndex(uint index) public view returns(bool success) { //(no se usa!)
            //para poder foldear...
            return(index >= 0 && index < DEVICE_AMOUNT_MAX-1);
        }
    */

    //-----------------------------------------------------------------
    //verificar que los arreglos de config keys no estén llenos--------

    //JAHALLA
    //CHECK, Verificar que haya espacio para un nuevo key-value pair para los compute nodes
    function canFitNewKeyForCNs() public view returns(bool success) {
        //para poder foldear...
        return(amount_keys_cn < CONFIG_VARS_MAX);
    }

    //JAHALLA
    //CHECK, Verificar que haya espacio para un nuevo key-value pair para los sensores
    function canFitNewKeyForSensors() public view returns(bool success) {
        //para poder foldear...
        return(amount_keys_s < CONFIG_VARS_MAX);
    }

    //JAHALLA
    //CHECK, Verificar que haya espacio para un nuevo key-value pair para los actuadores
    function canFitNewKeyForActuators() public view returns(bool success) {
        //para poder foldear...
        return(amount_keys_a < CONFIG_VARS_MAX);
    }

    //JAHALLA
    //CHECK, Verificar que haya espacio para un nuevo key-value pair para los sensores y actuadores
    function canFitNewKeyForSensorsAndActuators() public view returns(bool success) {
        //para poder foldear...
        return(amount_keys_sa < CONFIG_VARS_MAX);
    }

    //JAHALLA
    //CHECK, Verificar que haya espacio para un nuevo key-value pair para todos los dispositivos
    function canFitNewKeyForAll() public view returns(bool success) {
        //para poder foldear...
        return(amount_keys_all < CONFIG_VARS_MAX);
    }

    //---------------------------------------------------------------------------------------------------------------------------------------------
    //---UTILITY FUNCTIONS-------------------------------------------------------------------------------------------------------------------------

    //-----------------------------------------------------------------
    //swaps------------------------------------------------------------

    //JAHALLA
    //Intercambiar los índices de 2 dispositivos en la lista de IDs
    function swapDeviceIndices(uint i, uint j) public returns(bool success) {
        uint aux = ids[i];
        ids[i] = ids[j];
        ids[j] = aux;
        return true;
    }

    //JAHALLA
    //Intercambiar los índices de 2 sensores en la lista de IDs de sensores asociados a un CN
    function swapSubSensorIndices(uint cn_id, uint i, uint j) public returns(bool success) {
        uint aux = subsensors[cn_id][i];
        subsensors[cn_id][i] = subsensors[cn_id][j];
        subsensors[cn_id][j] = aux;
        return true;
    }

    //JAHALLA
    //Intercambiar los índices de 2 actuadores en la lista de IDs de actuadores asociados a un CN
    function swapSubActuatorIndices(uint cn_id, uint i, uint j) public returns(bool success) {
        uint aux = subactuators[cn_id][i];
        subactuators[cn_id][i] = subactuators[cn_id][j];
        subactuators[cn_id][j] = aux;
        return true;
    }

    //-----------------------------------------------------------------
    //zero shifts------------------------------------------------------

    //JAHALLA
    //Mandar los IDs en ceros hasta la derecha de la lista de IDs
    function zeroShiftDeviceArray() public returns(bool success) {

        uint i = 0;
        uint j = ids.length-1;

        while(i<j) {

            if(ids[i] > DEFAULT_ID) { //si i es un ID válido, revisar el siguiente
                i++;
            }else if(ids[i]==DEFAULT_ID && ids[j]==DEFAULT_ID) { //si ambos son cero, revisar el anterior con j
                j--;
            }else { //si i es cero y j es un ID válido, swappear y continuar
                swapDeviceIndices(i,j);
                i++;
                j--;
            }
        }

        return true;
    }

    //JAHALLA
    //Mandar los IDs en ceros hasta la derecha de la lista de sensores asociados a un CN
    function zeroShiftSubSensorArray(uint id) public returns(bool success) {

        uint i = 0;
        uint j = subsensors[id].length-1;

        while(i<j) {

            if(subsensors[id][i] > DEFAULT_ID) { //si i es un ID válido, revisar el siguiente
                i++;
            }else if(subsensors[id][i]==DEFAULT_ID && subsensors[id][j]==DEFAULT_ID) { //si ambos son cero, revisar el anterior con j
                j--;
            }else { //si i es cero y j es un ID válido, swappear y continuar
                swapSubSensorIndices(id,i,j);
                i++;
                j--;
            }
        }

        return true;
    }

    //JAHALLA
    //Mandar los IDs en ceros hasta la derecha de la lista de actuadores asociados a un CN
    function zeroShiftSubActuatorArray(uint id) public returns(bool success) {

        uint i = 0;
        uint j = subactuators[id].length-1;

        while(i<j) {

            if(subactuators[id][i] > DEFAULT_ID) { //si i es un ID válido, revisar el siguiente
                i++;
            }else if(subactuators[id][i]==DEFAULT_ID && subactuators[id][j]==DEFAULT_ID) { //si ambos son cero, revisar el anterior con j
                j--;
            }else { //si i es cero y j es un ID válido, swappear y continuar
                swapSubActuatorIndices(id,i,j);
                i++;
                j--;
            }
        }

        return true;
    }

    //-----------------------------------------------------------------
    //find ID----------------------------------------------------------

    //JAHALLA
    //Encontrar el índice de un ID en la lista de subsensores de un CN (sólo funciona sobre el array zeroshifteado)
    function findIDInSubSensorArray(uint cn_id, uint target) public view returns(uint devindex) {

        uint amount_children = readDeviceVariable(cn_id, AMOUNT_SENSORS);

        for(uint i=0; i<amount_children; i++) {
            if(target == subsensors[cn_id][i]) {
                return i;
            }
        }

        //la función que llame a esta debe saber que
        //si se retorna el valor DEVICE_AMOUNT_MAX-1 es que NO se encontró lo que buscaba
        return DEVICE_AMOUNT_MAX-1;
    }

    //JAHALLA
    //Encontrar el índice de un ID en la lista de subactuadores de un CN (sólo funciona sobre el array zeroshifteado)
    function findIDInSubActuatorArray(uint cn_id, uint target) public view returns(uint devindex) {

        uint amount_children = readDeviceVariable(cn_id, AMOUNT_ACTUATORS);

        for(uint i=0; i<amount_children; i++) {
            if(target == subactuators[cn_id][i]) {
                return i;
            }
        }

        //la función que llame a esta debe saber que
        //si se retorna el valor DEVICE_AMOUNT_MAX-1 es que NO se encontró lo que buscaba
        return DEVICE_AMOUNT_MAX-1;
    }

    //JAHALLA
    //Devuelve el ID de un dispositivo, buscando por índice
    function getDevice(uint index) public view returns(uint dev_id) {
        //para poder foldear...
        return ids[index];
    }

    //JAHALLA
    //Devuelve el ID de un subsensor, buscando por índice
    function getSubSensor(uint cn_id, uint index) public view returns(uint dev_id) {
        //para poder foldear...
        return subsensors[cn_id][index];
    }

    //JAHALLA
    //Devuelve el ID de un subactuador, buscando por índice
    function getSubActuator(uint cn_id, uint index) public view returns(uint dev_id) {
        //para poder foldear...
        return subactuators[cn_id][index];
    }

    //-----------------------------------------------------------------
    //add new ID-------------------------------------------------------

    //JAHALLA
    //Agregar un nuevo ID a la lista de dispositivos
    function insertIntoDeviceArray(uint new_id) public returns(bool success) {

        ids[amount_devices] = new_id;
        amount_devices++; //este debe ser el único lugar donde se incrementa esta variable
        //zeroShiftDeviceArray(); //no es necesario, asumiendo que antes de esta inserción el array ya estaba zeroshifteado
        return true;
    }

    //JAHALLA
    //Agregar un nuevo ID a la lista de sensores asociados a un CN
    function insertIntoSubSensorArray(uint cn_id, uint sa_id) public returns(bool success) {
        subsensors[cn_id][readDeviceVariable(cn_id, AMOUNT_SENSORS)] = sa_id;
        incrementDeviceVariable(cn_id, AMOUNT_SENSORS); //este debe ser el único lugar donde se incrementa esta variable
        //zeroShiftSubSensorArray(cn_id); //no es necesario, asumiendo que antes de esta inserción el array ya estaba zeroshifteado
        return true;
    }

    //JAHALLA
    //Agregar un nuevo ID a la lista de actuadores asociados a un CN
    function insertIntoSubActuatorArray(uint cn_id, uint sa_id) public returns(bool success) {
        subactuators[cn_id][readDeviceVariable(cn_id, AMOUNT_ACTUATORS)] = sa_id;
        incrementDeviceVariable(cn_id, AMOUNT_ACTUATORS); //este debe ser el único lugar donde se incrementa esta variable
        //zeroShiftSubActuatorArray(cn_id); //no es necesario, asumiendo que antes de esta inserción el array ya estaba zeroshifteado
        return true;
    }

    //JAHALLA
    //Generar un ID único e irrepetible para cada dispositivo conocido
    function generateUniqueID() public returns(uint new_id) {

        //idseq es el ID más grande que ha sido asignado a un dispositivo
        //y también el ID del último dispositivo que se ha creado
        uint try_this_id = idseq;

        do {
            try_this_id++;
        }while(findIDInDeviceArray(try_this_id) < DEVICE_AMOUNT_MAX);

        //en este punto try_this_id es un ID que nunca ha tenido un dispositivo asociado
        idseq = try_this_id;

        return try_this_id;
    }

    //-----------------------------------------------------------------
    //delete ID--------------------------------------------------------

    //JAHALLA
    //Eliminar un ID de la lista de dispositivos
    function deleteFromDeviceArray(uint index) public returns(bool success) {

        ids[index] = ids[ids.length-1]; //overwrite target with last (deletes target and duplicates last)
        ids[ids.length-1] = DEFAULT_ID; //set last to zero (removes duplicated last)

        amount_devices--; //este debe ser el único lugar donde se decrementa esta variable

        zeroShiftDeviceArray(); //por si quedó un cero entre ID's válidos

        return true;
    }

    //JAHALLA
    //Eliminar un ID de la lista de sensores asociados a un CN
    function deleteFromSubSensorArray(uint cn_id, uint index) public returns(bool success) {

        subsensors[cn_id][index] = subsensors[cn_id][subsensors[cn_id].length-1]; //overwrite target with last (deletes target and duplicates last)
        subsensors[cn_id][subsensors[cn_id].length-1] = DEFAULT_ID; //set last to zero (removes duplicated last)

        decrementDeviceVariable(cn_id, AMOUNT_SENSORS); //este debe ser el único lugar donde se decrementa esta variable

        zeroShiftSubSensorArray(cn_id); //por si quedó un cero entre ID's válidos

        return true;
    }

    //JAHALLA
    //Eliminar un ID de la lista de actuadores asociados a un CN
    function deleteFromSubActuatorArray(uint cn_id, uint index) public returns(bool success) {

        subactuators[cn_id][index] = subactuators[cn_id][subactuators[cn_id].length-1]; //overwrite target with last (deletes target and duplicates last)
        subactuators[cn_id][subactuators[cn_id].length-1] = DEFAULT_ID; //set last to zero (removes duplicated last)

        decrementDeviceVariable(cn_id, AMOUNT_ACTUATORS); //este debe ser el único lugar donde se decrementa esta variable

        zeroShiftSubActuatorArray(cn_id); //por si quedó un cero entre ID's válidos

        return true;
    }

    //-----------------------------------------------------------------
    //linkear y deslinkear CNs y satélites-----------------------------

    //JAHALLA
    //Desasociar un sensor o actuador de un compute node
    function unlinkDeviceFromComputeNode(uint sa_id, uint sa_tipo, uint sa_index, uint cn_id) public returns(bool success) {

        //borrar dispositivo de la lista de sensores/actuadores del CN
        if(sa_tipo==SENSOR) {
            deleteFromSubSensorArray(cn_id, sa_index); //aquí se hace un zeroShift y se decrementa el contador de subsensores
        }else if(sa_tipo==ACTUATOR){
            deleteFromSubActuatorArray(cn_id, sa_index); //aquí se hace un zeroShift y se decrementa el contador de subactuadores
        }

        //dejar en blanco el CN del dispositivo
        writeDeviceVariable(sa_id, PARENT, DEFAULT_ID);

        return true;
    }

    //JAHALLA
    //TERMINAL - Asociar un sensor o actuador con un compute node
    function linkDeviceToComputeNode(uint sa_id, uint cn_id) public returns(bool success) {

        //saber si el dispositivo nuevo es CN, sensor o actuador
        uint tipo_sa = readDeviceVariable(sa_id, TYPE);

        //agregar el dispositivo a su lista de sensores/actuadores asociados
        if(tipo_sa==SENSOR) {
            insertIntoSubSensorArray(cn_id, sa_id); //aquí también se incrementa el contador de subsensores
        }else if(tipo_sa==ACTUATOR) {
            insertIntoSubActuatorArray(cn_id, sa_id); //aquí también se incrementa el contador de subactuadores
        }

        //setear el CN como padre del dispositivo nuevo
        writeDeviceVariable(sa_id, PARENT, cn_id);

        return true;
    }

    /*//WRAPPER de linkDeviceToComputeNode - Asociar un sensor o actuador con un compute node
        //JAHALLA
        function linkSubDevice(uint sa_id, uint new_cn) public returns(bool success) {

            //require(deviceExists(new_cn) && isComputeNode(new_cn), "DDE+NCN03");
            //require(deviceExists(sa_id) && !hasParent(sa_id) && ( (isSensor(sa_id) && newSensorStillFitsCN(new_cn) ) || (isActuator(sa_id) && newActuatorStillFitsCN(new_cn) ) ), "DDE+HPA+SDF+ADF01");

            linkDeviceToComputeNode(sa_id, new_cn); //si pasa las validaciones, llega a la función wrappeada
            return true;
        }
    */

    //-----------------------------------------------------------------
    //bulk CRUD operations---------------------------------------------

    //JAHALLA
    //Crear / Editar parámetro de configuración de todos los dispositivos
    function bulkWriteDeviceVariable(uint key, uint value) public returns(bool success) {

        for(uint i=0; i<amount_devices; i++) {
            writeDeviceVariable(ids[i], key, value);
        }

        return true;
    }

    //JAHALLA
    //Crear / Editar parámetro de configuración de todos los sensores asociados a un CN
    function bulkWriteSubSensorVariable(uint cn_id, uint key, uint value) public returns(bool success) {

        uint amount_children = readDeviceVariable(cn_id, AMOUNT_SENSORS);

        for(uint i=0; i<amount_children; i++) {
            writeDeviceVariable(subsensors[cn_id][i], key, value);
        }

        return true;
    }

    //JAHALLA
    //Crear / Editar parámetro de configuración de todos los actuadores asociados a un CN
    function bulkWriteSubActuatorVariable(uint cn_id, uint key, uint value) public returns(bool success) {

        uint amount_children = readDeviceVariable(cn_id, AMOUNT_ACTUATORS);

        for(uint i=0; i<amount_children; i++) {
            writeDeviceVariable(subactuators[cn_id][i], key, value);
        }

        return true;
    }

    //-----------------------------------------------------------------
    //operaciones con los key-values de config-----------------

    //JAHALLA
    //TERMINAL - Aplicar una configuración por default para cada tipo de dispositivo
    function applyDefaultConfig(uint id, uint tipo) public returns(bool success) {

        //por lo pronto jala para un sistema de alumbrado sencillo...
        //que otro usuario agregue más variables a su caso de uso...
        //a fin de cuentas debe ser generalizable y customizable...

        //no tocar PARENT, AMOUNT_SENSORS ni AMOUNT_ACTUATORS o tendría que hacer unlinks.

        writeDeviceVariable(id, ID, id); //510
        writeDeviceVariable(id, TYPE, tipo); //520
        writeDeviceVariable(id, PUBLIC_KEY, DEFAULT_VALUE); //530
        writeDeviceVariable(id, PERMISSION, LOW); //540
        writeDeviceVariable(id, ON_OFF_STATUS, LOW); //550

        if(tipo==COMPUTE_NODE) {
            //para poder foldear...
            writeDeviceVariable(id, THRESHOLD, DEFAULT_VALUE); //130
        }else if(tipo==SENSOR) {
            //para poder foldear...
            writeDeviceVariable(id, LAST_READING, DEFAULT_VALUE); //210
        }else if(tipo==ACTUATOR) {
            //para poder foldear...
            writeDeviceVariable(id, ACT_COMMAND, LOW); //310
        }

        return true;
    }

    /*//WRAPPER de applyDefaultConfig - Aplicar una configuración por default para cada tipo de dispositivo
        //JAHALLA
        function resetDeviceToDefault(uint id, uint tipo) public returns(bool success) {
            //require(deviceExists(id), "DDE10");
            applyDefaultConfig(id, tipo); //si pasa las validaciones, llega a la función wrappeada
            return true;
        }
    */

    //JAHALLA
    //Borrar todos los values del key-value de config de un dispositivo
    function clearDeviceConfig(uint id) public returns(bool success) {

        //En solidity, no es posible eliminar keys de los mappings,
        //Tampoco es posible eliminar sus values,
        //Sólo es posible resetear sus values a cero.

        uint tipo = readDeviceVariable(id, TYPE);

        //borrar variables de un solo tipo de dispositivo
        if(tipo==COMPUTE_NODE) {
            for(uint i=0; i<amount_keys_cn; i++) {
                deleteDeviceVariable(id, configkeys_cn[i]);
            }
        }else if(tipo==SENSOR) {
            for(uint i=0; i<amount_keys_s; i++) {
                deleteDeviceVariable(id, configkeys_s[i]);
            }
        }else if(tipo==ACTUATOR) {
            for(uint i=0; i<amount_keys_a; i++) {
                deleteDeviceVariable(id, configkeys_a[i]);
            }
        }

        //borrar variables presentes tanto en sensores como en actuadores
        if(tipo==SENSOR || tipo==ACTUATOR) {
            for(uint i=0; i<amount_keys_sa; i++) {
                deleteDeviceVariable(id, configkeys_sa[i]);
            }
        }

        //borrar variables de todos los dispositivos
        for(uint i=0; i<amount_keys_all; i++) {
            deleteDeviceVariable(id, configkeys_all[i]);
        }

        return true;
    }

    //JAHALLA
    //Clonar la config de un sensor o actuador a otro igual
    function cloneConfig(uint id_src, uint id_dest) public returns(bool success) {

        //clonando el 49 en el 86
        //ID:49|TYPE:1|PUBLIC_KEY:378537|PERMISSION:10|ON_OFF_STATUS:10|PARENT:36|LAST_READING:999 <--original
        //ID:86|TYPE:1|PUBLIC_KEY:200356|PERMISSION:11|ON_OFF_STATUS:11|PARENT:00|LAST_READING:0 <-- antes
        //ID:86|TYPE:1|PUBLIC_KEY:378537|PERMISSION:10|ON_OFF_STATUS:10|PARENT:36|LAST_READING:999 <-- después

        uint tipo = readDeviceVariable(id_src, TYPE);

        //clonar todas las variables pertinentes excepto ID y TYPE
        //ID puede ser diferente, TYPE ya debería ser igual
        //sólo está pensada para jalar con sensores y/o actuadores

        if(tipo==SENSOR) {
            writeDeviceVariable(id_dest, LAST_READING, readDeviceVariable(id_src, LAST_READING));
        }else if(tipo==ACTUATOR) {
            writeDeviceVariable(id_dest, ACT_COMMAND,  readDeviceVariable(id_src, ACT_COMMAND));
        }

        writeDeviceVariable(id_dest, PARENT,        readDeviceVariable(id_src, PARENT));
        writeDeviceVariable(id_dest, PUBLIC_KEY,    readDeviceVariable(id_src, PUBLIC_KEY));
        writeDeviceVariable(id_dest, PERMISSION,    readDeviceVariable(id_src, PERMISSION));
        writeDeviceVariable(id_dest, ON_OFF_STATUS, readDeviceVariable(id_src, ON_OFF_STATUS));

        return true;
    }

    //JAHALLA
    //TERMINAL - Agregar un nuevo key-value de config a los CNs (1xx) (default: 3)
    function addCNKey(uint key) public returns(bool success) {
        configkeys_cn[amount_keys_cn] = key;
        amount_keys_cn++; //default: 3
        return true;
    }

    /*//WRAPPER de addCNKey - Agregar un nuevo key-value de config a los CNs (1xx)
        //JAHALLA
        function addNewConfigKeyForCNs(uint key) public returns(bool success) {
            //require(canFitNewKeyForCNs(), "KCN");
            addCNKey(key); //si pasa las validaciones, llega a la función wrappeada
            return true;
        }
    */

    //JAHALLA
    //TERMINAL - Agregar un nuevo key-value de config a los Sensores (2xx) (default: 1)
    function addSensorKey(uint key) public returns(bool success) {
        configkeys_s[amount_keys_s] = key;
        amount_keys_s++; //default: 1
        return true;
    }

    /*//WRAPPER de addSensorKey - Agregar un nuevo key-value de config a los Sensores (2xx)
        //JAHALLA
        function addNewConfigKeyForSensors(uint key) public returns(bool success) {
            //require(canFitNewKeyForSensors(), "KSN");
            addSensorKey(key); //si pasa las validaciones, llega a la función wrappeada
            return true;
        }
    */

    //JAHALLA
    //TERMINAL - Agregar un nuevo key-value de config a los Actuadores (3xx) (default: 1)
    function addActuatorKey(uint key) public returns(bool success) {
        configkeys_a[amount_keys_a] = key;
        amount_keys_a++; //default: 1
        return true;
    }

    /*//WRAPPER de addActuatorKey - Agregar un nuevo key-value de config a los Actuadores (3xx)
        //JAHALLA
        function addNewConfigKeyForActuators(uint key) public returns(bool success) {
            //require(canFitNewKeyForActuators(), "KAC");
            addActuatorKey(key); //si pasa las validaciones, llega a la función wrappeada
            return true;
        }
    */

    //JAHALLA
    //TERMINAL - Agregar un nuevo key-value de config a los Sensores y Actuadores (4xx) (default: 1)
    function addSatelliteKey(uint key) public returns(bool success) {
        configkeys_sa[amount_keys_sa] = key;
        amount_keys_sa++; //default: 1
        return true;
    }

    /*//WRAPPER de addSatelliteKey - Agregar un nuevo key-value de config a los Sensores y Actuadores (4xx)
        //JAHALLA
        function addNewConfigKeyForSensorsAndActuators(uint key) public returns(bool success) {
            //require(canFitNewKeyForSensorsAndActuators(), "KST");
            addSatelliteKey(key); //si pasa las validaciones, llega a la función wrappeada
            return true;
        }
    */

    //JAHALLA
    //TERMINAL - Agregar un nuevo key-value de config a todos los dispositivos (5xx) (default: 5)
    function addDeviceKey(uint key) public returns(bool success) {
        configkeys_all[amount_keys_all] = key;
        amount_keys_all++; //default: 5
        return true;
    }

    /*//WRAPPER de addDeviceKey - Agregar un nuevo key-value de config a todos los dispositivos (5xx)
        //JAHALLA
        function addNewConfigKeyForAll(uint key) public returns(bool success) {
            //require(canFitNewKeyForAll(), "KDV");
            addDeviceKey(key); //si pasa las validaciones, llega a la función wrappeada
            return true;
        }
    */

    //-----------------------------------------------------------------
    //alta y baja de dispositivos--------------------------------------

    //JAHALLA
    //TERMINAL - Alta de un dispositivo
    function createDevice(uint tipo) public returns(uint new_dev_id) {

        generateUniqueID(); //esto guarda el nuevo ID en idseq

        insertIntoDeviceArray(idseq); //agregar ID de nuevo dispositivo a la lista de IDs dados de alta

        //bug en potencia: aquí tengo que usar clearDeviceConfig() en el nuevo dispositivo
        //pero me lo voy a brincar porque YOLO...

        applyDefaultConfig(idseq, tipo); //setear con valores default las variables del nuevo dispositivo

        return idseq;
    }

    /*//WRAPPER de createDevice - Alta de un dispositivo
        //JAHALLA
        function makeNewDevice(uint tipo) public returns(uint new_dev_id) {
            //require(newDeviceStillFits(), "DDF01");
            return createDevice(tipo); //si pasa las validaciones, llega a la función wrappeada
        }
    */

    //JAHALLA
    //Borra un dispositivo del mapping global de dispositivos y de la lista global de dispositivos
    function removeDevice(uint id, uint devindex) public returns(bool success) {

        //eliminar las variables de config del dispositivo
        clearDeviceConfig(id);

        //borrar al dispositivo de la lista de IDs
        deleteFromDeviceArray(devindex); //aquí dentro se decrementa el contador de dispositivos y hace un zeroShift

        return true;
    }

    //JAHALLA
    //Eliminar un sensor o actuador y primero lo deslinkea de su CN
    function deleteSatellite(uint id, uint devindex, uint sa_tipo, uint parent_cn, uint subindex) public returns(bool success) {

        //si tiene CN padre, deslinkearlo de él
        if(parent_cn > DEFAULT_ID) {
            unlinkDeviceFromComputeNode(id, sa_tipo, subindex, parent_cn);
        }

        //eliminar las variables de config del dispositivo,
        //borrar al dispositivo de la lista de IDs,
        //hacer un zeroShift de la lista de IDs,
        //y decrementar el contador de dispositivos
        removeDevice(id, devindex);

        return true;
    }

    //JAHALLA
    //Eliminar los subsensores de un CN
    function deleteSubSensors(uint cn_id) public returns(bool success) {

        while(readDeviceVariable(cn_id, AMOUNT_SENSORS) > 0) {
            deleteSatellite(
                subsensors[cn_id][0], //usa el índice cero porque cada loop hace un zeroShift
                findIDInDeviceArray(subsensors[cn_id][0]),
                SENSOR,
                cn_id,
                0
            );
        }

        return true;
    }

    //JAHALLA
    //Eliminar los subactuadores de un CN
    function deleteSubActuators(uint cn_id) public returns(bool success) {

        while(readDeviceVariable(cn_id, AMOUNT_ACTUATORS) > 0) {
            deleteSatellite(
                subactuators[cn_id][0], //usa el índice cero porque cada loop hace un zeroShift
                findIDInDeviceArray(subactuators[cn_id][0]),
                ACTUATOR,
                cn_id,
                0
            );
        }

        return true;
    }

    //JAHALLA
    //Eliminar un compute node y primero elimina todos sus satelites
    function deleteComputeNode(uint id, uint devindex) public returns(bool success) {

        /*pruebas

            devices, original:
            26:CN | 12:S | 14:S | 16:A | 69:A | 36:CN | 49:S | 45:S | 78:A | 76:A | 86:S | 87:S | 88:A
            --0   |   1  |   2  |   3  |   4  |   5   |   6  |   7  |   8  |   9  |  10  |  11  |  12

            devices, tras borrar subsensores:
            26:CN | 88:A | 87:S | 16:A | 69:A | 36:CN | 49:S | 45:S | 78:A | 76:A | 86:S
            --0   |   1  |   2  |   3  |   4  |   5   |   6  |   7  |   8  |   9  |  10

            devices, tras borrar subactuadores:
            26:CN | 88:A | 87:S | 86:S | 76:A | 36:CN | 49:S | 45:S | 78:A
            --0   |   1  |   2  |   3  |   4  |   5   |   6  |   7  |   8

            devices, tras borrar el compute node:
            78:A | 88:A | 87:S | 86:S | 76:A | 36:CN | 49:S | 45:S
            --0  |   1  |   2  |   3  |   4  |   5   |   6  |   7

            satélites, original: S:12,14|A:16,69
            satélites, tras borrar subsensores: S:|A:16,69
            satélites, tras borrar subactuadores: S:|A:
            satélites, tras borrar el compute node: S:|A:

            config, original
            26: ID:26|TYPE:3|PUBLIC_KEY:113634|PERMISSION:11|ON_OFF_STATUS:11|AMOUNT_SENSORS:2|AMOUNT_ACTUATORS:2|THRESHOLD:0
            12: ID:12|TYPE:1|PUBLIC_KEY:443853|PERMISSION:11|ON_OFF_STATUS:11|PARENT:26|LAST_READING:0
            14: ID:14|TYPE:1|PUBLIC_KEY:859867|PERMISSION:11|ON_OFF_STATUS:11|PARENT:26|LAST_READING:0
            16: ID:16|TYPE:2|PUBLIC_KEY:735896|PERMISSION:11|ON_OFF_STATUS:11|PARENT:26|ACT_COMMAND:10
            69: ID:69|TYPE:2|PUBLIC_KEY:985953|PERMISSION:11|ON_OFF_STATUS:11|PARENT:26|ACT_COMMAND:10

            config, tras borrar subsensores:
            26: ID:26|TYPE:3|PUBLIC_KEY:113634|PERMISSION:11|ON_OFF_STATUS:11|AMOUNT_SENSORS:0|AMOUNT_ACTUATORS:2|THRESHOLD:0
            12: ID:0|TYPE:0|PUBLIC_KEY:0|PERMISSION:0|ON_OFF_STATUS:0
            14: ID:0|TYPE:0|PUBLIC_KEY:0|PERMISSION:0|ON_OFF_STATUS:0
            16: ID:16|TYPE:2|PUBLIC_KEY:735896|PERMISSION:11|ON_OFF_STATUS:11|PARENT:26|ACT_COMMAND:10
            69: ID:69|TYPE:2|PUBLIC_KEY:985953|PERMISSION:11|ON_OFF_STATUS:11|PARENT:26|ACT_COMMAND:10

            config, tras borrar subactuadores:
            26: ID:26|TYPE:3|PUBLIC_KEY:113634|PERMISSION:11|ON_OFF_STATUS:11|AMOUNT_SENSORS:0|AMOUNT_ACTUATORS:0|THRESHOLD:0
            12: ID:0|TYPE:0|PUBLIC_KEY:0|PERMISSION:0|ON_OFF_STATUS:0
            14: ID:0|TYPE:0|PUBLIC_KEY:0|PERMISSION:0|ON_OFF_STATUS:0
            16: ID:0|TYPE:0|PUBLIC_KEY:0|PERMISSION:0|ON_OFF_STATUS:0
            69: ID:0|TYPE:0|PUBLIC_KEY:0|PERMISSION:0|ON_OFF_STATUS:0

            config, tras borrar el compute node:
            26: ID:0|TYPE:0|PUBLIC_KEY:0|PERMISSION:0|ON_OFF_STATUS:0
            12: ID:0|TYPE:0|PUBLIC_KEY:0|PERMISSION:0|ON_OFF_STATUS:0
            14: ID:0|TYPE:0|PUBLIC_KEY:0|PERMISSION:0|ON_OFF_STATUS:0
            16: ID:0|TYPE:0|PUBLIC_KEY:0|PERMISSION:0|ON_OFF_STATUS:0
            69: ID:0|TYPE:0|PUBLIC_KEY:0|PERMISSION:0|ON_OFF_STATUS:0
        */

        //borrar a todos los subsensores
        deleteSubSensors(id);

        //borrar a todos los subactuadores
        deleteSubActuators(id);

        //al llegar aquí ya se borraron todos los satélites del CN
        //entonces ya podemos vaciar sus listas de satélites
        delete subsensors[id];
        delete subactuators[id];

        //eliminar las variables de config del dispositivo,
        //borrar al dispositivo de la lista de IDs,
        //hacer un zeroShift de la lista de IDs,
        //y decrementar el contador de dispositivos
        removeDevice(id, devindex);

        return true;
    }

    //-----------------------------------------------------------------
    //output de variables internas para debuggear----------------------

    //JAHALLA
    //TERMINAL - Retorna un string con toda la config de un dispositivo
    function getDeviceInfo(uint id) public view returns(string memory devicedata) {

        //pruebas:
        //sensor:      ID:49|TYPE:1|PUBLIC_KEY:378537|PERMISSION:11|ON_OFF_STATUS:11|PARENT:36|LAST_READING:0
        //actuador:    ID:69|TYPE:2|PUBLIC_KEY:985953|PERMISSION:11|ON_OFF_STATUS:11|PARENT:26|ACT_COMMAND:10
        //computenode: ID:26|TYPE:3|PUBLIC_KEY:113634|PERMISSION:11|ON_OFF_STATUS:11|AMOUNT_SENSORS:2|AMOUNT_ACTUATORS:2|THRESHOLD:0

        uint tipo = readDeviceVariable(id, TYPE);

        string memory keyvalues = string.concat(
            "ID:",             Strings.toString(readDeviceVariable(id,ID)),           //all
            "|TYPE:",          Strings.toString(readDeviceVariable(id,TYPE)),         //all
            "|PUBLIC_KEY:",    Strings.toString(readDeviceVariable(id,PUBLIC_KEY)),   //all
            "|PERMISSION:",    Strings.toString(readDeviceVariable(id,PERMISSION)),   //all
            "|ON_OFF_STATUS:", Strings.toString(readDeviceVariable(id,ON_OFF_STATUS)) //all
        );

        if(tipo==COMPUTE_NODE) {
            keyvalues = string.concat(
                keyvalues,
                "|AMOUNT_SENSORS:",   Strings.toString(readDeviceVariable(id,AMOUNT_SENSORS)),   //CN
                "|AMOUNT_ACTUATORS:", Strings.toString(readDeviceVariable(id,AMOUNT_ACTUATORS)), //CN
                "|THRESHOLD:",        Strings.toString(readDeviceVariable(id,THRESHOLD))         //CN
            );
        }else if(tipo==SENSOR) {
            keyvalues = string.concat(
                keyvalues,
                "|PARENT:",       Strings.toString(readDeviceVariable(id,PARENT)),      //SA
                "|LAST_READING:", Strings.toString(readDeviceVariable(id,LAST_READING)) //S
            );
        }else if(tipo==ACTUATOR) {
            keyvalues = string.concat(
                keyvalues,
                "|PARENT:",      Strings.toString(readDeviceVariable(id,PARENT)),     //SA
                "|ACT_COMMAND:", Strings.toString(readDeviceVariable(id,ACT_COMMAND)) //A
            );
        }

        return keyvalues;
    }

    /*//WRAPPER de getDeviceInfo - Retorna un string con toda la config de un dispositivo
        //JAHALLA
        function deviceInfoToString(uint id) public view returns(string memory devicedata) {
            //require(deviceExists(id), "DDE04");
            return getDeviceInfo(id); //si pasa las validaciones, llega a la función wrappeada
        }
    */

    //JAHALLA
    //TERMINAL - Retorna un string con los IDs de los satelites de un CN
    function getSatellites(uint id) public view returns(string memory satellites) {

        //pruebas
        //CN#26: S:12,14|A:16,69
        //CN#36: S:49,45|A:78,76

        uint children_s = readDeviceVariable(id, AMOUNT_SENSORS);
        uint children_a = readDeviceVariable(id, AMOUNT_ACTUATORS);

        string memory subdevices = "S:";

        for(uint i=0; i<children_s; i++) {
            subdevices = string.concat(subdevices, Strings.toString(subsensors[id][i]));
            if(i < children_s-1) {
                subdevices = string.concat(subdevices, ",");
            }
        }

        subdevices = string.concat(subdevices, "|A:");

        for(uint i=0; i<children_a; i++) {
            subdevices = string.concat(subdevices, Strings.toString(subactuators[id][i]));
            if(i < children_a-1) {
                subdevices = string.concat(subdevices, ",");
            }
        }

        return subdevices;
    }

    /*//WRAPPER de getSatellites - Retorna un string con los IDs de los satelites de un CN
        //JAHALLA
        function satelliteListToString(uint id) public view returns(string memory satellites) {
            //require(deviceExists(id) && isComputeNode(id), "DDE+NCN01");
            return getSatellites(id); //si pasa las validaciones, llega a la función wrappeada
        }
    */

    //JAHALLA
    //TERMINAL - Retorna una lista de los IDs de todos los dispositivos
    function getDevices() public view returns(string memory devicelist) {

        //prueba
        //26:CN,12:S,14:S,16:A,69:A,36:CN,49:S,45:S,78:A,76:A,86:S,87:S,88:A

        string memory devlist = "";
        uint tipo;
        string memory t_letter;

        for(uint i=0; i<amount_devices; i++) {

            tipo = readDeviceVariable(ids[i], TYPE);

            if(tipo==COMPUTE_NODE) {
                t_letter = "CN";
            }else if(tipo==SENSOR) {
                t_letter = "S";
            }else if(tipo==ACTUATOR) {
                t_letter = "A";
            }

            devlist = string.concat(devlist, Strings.toString(ids[i]), ":", t_letter);

            if(i < amount_devices-1) {
                devlist = string.concat(devlist, ",");
            }
        }

        return devlist;
    }

    /*//WRAPPER de getDevices - Retorna una lista de los IDs de todos los dispositivos
        //JAHALLA
        function deviceListToString() public view returns(string memory devicelist) {
            //require(knownDevicesExist(), "NKD01");
            return getDevices(); //si pasa las validaciones, llega a la función wrappeada
        }
    */

    //---------------------------------------------------------------------------------------------------------------------------------------------
    //---MGMT FUNCTIONS----------------------------------------------------------------------------------------------------------------------------

    //-------------------------------------------------------------
    //Simple Config & State Changes--------------------------------

    //JAHALLA
    //TERMINAL - Ping al back-end para pruebas de conectividad
    function pingBackEnd() public view returns(bool success) {
        //para poder foldear...
        return pingvalue; //siempre es true
    }

    //JAHALLA
    //TERMINAL - Devuelve el ID del último dispositivo que se ha creado
    function getLatestID() public view returns(uint latestid) {
        //para poder foldear...
        return idseq;
    }

    //JAHALLA
    //TERMINAL - Autenticar un dispositivo
    function authDevice(uint id) public view returns(uint devpubkey) {

        //proceso de autenticación:
            //GAMA manda a python un mensaje de parte de 1 dispositivo
            //el mensaje está firmado con su llave privada
            //en python, se recibe y guarda el mensaje
            //python llama a esta función en ETH para pedir la llave pública del dispositivo
            //obtenemos del ledger la llave pública del dispositivo y la retornamos a python
            //desencriptamos en python el mensaje usando la llave pública
            //si sí se deja desencriptar, lo autenticamos
        //

        //para setear la llave pública de un dispositivo en el ledger
        //basta con mandarla con la función writeDeviceVariable() u otra función que la wrapée

        //require(deviceExists(id), "DDE05");
        return readDeviceVariable(id, PUBLIC_KEY);
    }

    //JAHALLA
    //TERMINAL - Otorgar permisos a un dispositivo
    function grantPerms(uint id) public returns(bool success) {
        //require(deviceExists(id), "DDE06");
        writeDeviceVariable(id, PERMISSION, HIGH);
        return true;
    }

    //JAHALLA
    //TERMINAL - Denegar permisos a un dispositivo
    function denyPerms(uint id) public returns(bool success) {

        //require(deviceExists(id), "DDE07");

        writeDeviceVariable(id, PERMISSION, LOW);

        //si es un CN, cascadear la negación de permisos a sus S/A
        if(readDeviceVariable(id, TYPE) == COMPUTE_NODE) {
            bulkWriteSubSensorVariable(id, PERMISSION, LOW);
            bulkWriteSubActuatorVariable(id, PERMISSION, LOW);
        }
        return true;
    }

    //JAHALLA
    //TERMINAL - Encender dispositivo
    function turnOnDevice(uint id) public returns(bool success) {
        //require(deviceExists(id), "DDE08");
        writeDeviceVariable(id, ON_OFF_STATUS, HIGH);
        return true;
    }

    //JAHALLA
    //TERMINAL - Apagar dispositivo
    function turnOffDevice(uint id) public returns(bool success) {

        //require(deviceExists(id), "DDE09");

        writeDeviceVariable(id, ON_OFF_STATUS, LOW);

        //si es un CN, cascadear el apagado a sus S/A
        if(readDeviceVariable(id, TYPE) == COMPUTE_NODE) {
            bulkWriteSubSensorVariable(id, ON_OFF_STATUS, LOW);
            bulkWriteSubActuatorVariable(id, ON_OFF_STATUS, LOW);
        }

        return true;
    }

    //JAHALLA
    //TERMINAL - Encender todos los dispositivos
    function turnOnAllDevices() public returns(bool success) {
        //require(knownDevicesExist(), "NKD02");
        bulkWriteDeviceVariable(ON_OFF_STATUS, HIGH);
        return true;
    }

    //JAHALLA
    //TERMINAL - Apagar todos los dispositivos
    function turnOffAllDevices() public returns(bool success) {
        //require(knownDevicesExist(), "NKD03");
        bulkWriteDeviceVariable(ON_OFF_STATUS, LOW);
        return true;
    }

    //-------------------------------------------------------------
    //Complex Config & State Changes-------------------------------

    //JAHALLA
    //TERMINAL - Escribir en el ledger la lectura de un sensor
    function uploadReading(uint cn_id, uint sensor_id, uint reading) public returns(bool success) {

        //esta función debe triggerearse cada vez que un sensor (en GAMA) realiza una lectura.

        //require(deviceExists(cn_id) && isComputeNode(cn_id), "DDE+NCN02");
        //require(deviceExists(sensor_id) && isSensor(sensor_id) && isChildOfCN(cn_id, sensor_id), "DDE+NSN+NCH01");

        //cual es el threshold, status y permisos del CN
        uint cn_threshold = readDeviceVariable(cn_id, THRESHOLD);
        uint cn_perms     = readDeviceVariable(cn_id, PERMISSION);
        uint cn_status    = readDeviceVariable(cn_id, ON_OFF_STATUS);

        //cual es el status y permisos del sensor
        uint sensor_perms  = readDeviceVariable(sensor_id, PERMISSION);
        uint sensor_status = readDeviceVariable(sensor_id, ON_OFF_STATUS);

        //si el threshold no está seteado, o si el CN o el sensor no tienen permisos o si están apagados
        //esta operación no se debe realizar
        if(cn_threshold==DEFAULT_VALUE || cn_perms<HIGH || cn_status<HIGH || sensor_perms<HIGH || sensor_status<HIGH) {
            return false;
        }

        //guardar el valor sensado en la config del sensor
        writeDeviceVariable(sensor_id, LAST_READING, reading);

        return true;
    }

    //TERMINAL - Evaluar si según las lecturas de los sensores de un CN, sus actuadores deben triggerearse
    function evalSensors(uint cn_id) public returns(bool success) {

        //esta función debe triggerearse cada vez que todos los sensores del mismo CN (en GAMA) realizan una lectura.

        //aquí irían los requires pero meh...

        //cual es el threshold, permisos y status del CN
        uint threshold = readDeviceVariable(cn_id, THRESHOLD);
        uint perms     = readDeviceVariable(cn_id, PERMISSION);
        uint status    = readDeviceVariable(cn_id, ON_OFF_STATUS);

        //si el threshold no está seteado, o si el CN no tiene permisos o si está apagado
        //esta operación no se debe realizar
        if(threshold==DEFAULT_VALUE || perms<HIGH || status<HIGH) {
            return false;
        }

        //cuantos subsensores hay en total
        uint amount_sensors = readDeviceVariable(cn_id, AMOUNT_SENSORS);

        //comenzar un proceso en el que checamos si la mayoría de los sensores
        //reportan lecturas que rebasan el threshold de su CN
        uint superiors = 0; //cuantos reportan lecturas mayores al threshold
        uint inferiors = 0; //cuantos reportan lecturas menores o iguales al threshold

        //valores de todos los subsensores del mismo CN
        uint curr_status;
        uint curr_perms;
        uint curr_reading;

        //contar cuantos reportan lecturas mayores y menores al threshold
        for(uint i=0; i<amount_sensors; i++) {

            curr_status  = readDeviceVariable( getSubSensor(cn_id,i), ON_OFF_STATUS );
            curr_perms   = readDeviceVariable( getSubSensor(cn_id,i), PERMISSION );
            curr_reading = readDeviceVariable( getSubSensor(cn_id,i), LAST_READING );

            if(curr_status<HIGH || curr_perms<HIGH || curr_reading==threshold) { //sensor apagado, sin permisos o igual al threshold, no cuenta
                continue;
            }else if(curr_reading > threshold) {
                superiors++;
            }else if(curr_reading < threshold) {
                inferiors++;
            }
        }

        //ESTA LÓGICA ES PARA UN SISTEMA QUE ENCIENDE LUZ ARTIFICIAL CUANDO FALTA LUZ NATURAL
        //AL FALTAR LUZ NATURAL, SE ENCIENDEN LOS FOCOS (AL NO REBASAR EL THRESHOLD, SE ENCIENDEN LOS ACTUADORES)
        //AL DETECTAR LUZ NATURAL, SE APAGAN LOS FOCOS (AL REBASAR EL THRESHOLD, SE DETIENEN LOS ACTUADORES)
        //SI NO SE PUEDE DETERMINAR LA CANTIDAD DE LUZ NATURAL, DEJAR TODO IGUAL

        if(superiors > inferiors) {
            bulkWriteSubActuatorVariable(cn_id, ACT_COMMAND, LOW); //si se detecta luz, apagar los focos
        }else if(superiors < inferiors) {
            bulkWriteSubActuatorVariable(cn_id, ACT_COMMAND, HIGH); //si falta luz, prender los focos
        }

        return true;
    }

    //TERMINAL - Devuelve el comando de actuación de los actuadores de un CN
    function reportCommand(uint cn_id) public view returns(uint command) {

        //si el CN no tuviera subactuadores, devolver el default
        if(readDeviceVariable(cn_id, AMOUNT_ACTUATORS) == 0) {
            return DEFAULT_VALUE;
        }

        //devolver el valor de command de un subactuador cualquiera
        //al cabo que todos deben tener el mismo
        return readDeviceVariable( getSubActuator(cn_id,0), ACT_COMMAND );
    }

    //JAHALLA
    //TERMINAL - Desasociar un sensor o actuador de un compute node
    function unlinkSubDevice(uint sa_id) public returns(bool success) {

        //require(deviceExists(sa_id) && isSensorOrActuator(sa_id) && hasParent(sa_id), "DDE+NSN+NAC+NCH01");

        //saber si es sensor o actuador
        uint sa_tipo = readDeviceVariable(sa_id, TYPE);

        //saber quién es el CN del dispositivo a borrar
        uint parent_cn = readDeviceVariable(sa_id, PARENT);

        //saber el índice del S/A en el arreglo de satélites del CN
        uint sa_index;

        //checar si el índice que buscamos eliminar existe
        if(sa_tipo==SENSOR) {
            sa_index = findIDInSubSensorArray(parent_cn, sa_id); //encontrar el sensor en la lista
            //require(canUnlinkSensor(parent_cn, sa_index), "CUS01");
        }else if(sa_tipo==ACTUATOR){
            sa_index = findIDInSubActuatorArray(parent_cn, sa_id); //encontrar el actuador en la lista
            //require(canUnlinkActuator(parent_cn, sa_index), "CUA01");
        }

        unlinkDeviceFromComputeNode(sa_id, sa_tipo, sa_index, parent_cn);

        return true;
    }

    //JAHALLA
    //TERMINAL - Eliminar un sensor o actuador y primero lo deslinkea de su CN
    function destroySatellite(uint id) public returns(bool success) {

        //IMPORTANTE: desde GAMA ya se debe saber el tipo de dispositivo
        //y llamar a la función correcta para eliminarlo
        //puede ser esta o destroyComputeNode()

        uint devindex = findIDInDeviceArray(id);

        //require(canDeleteDevice(devindex) && isSensorOrActuator(id), "CDD+NSN+NAC01");

        uint sa_tipo = readDeviceVariable(id, TYPE);
        uint parent_cn = readDeviceVariable(id, PARENT);
        uint subindex;

        if(parent_cn > DEFAULT_ID) { //si tiene CN padre, deslinkearlo de él

            if(sa_tipo==SENSOR) {
                subindex = findIDInSubSensorArray(parent_cn, id);
                //require(canUnlinkSensor(parent_cn, subindex), "CUS02");
            }else if(sa_tipo==ACTUATOR) {
                subindex = findIDInSubActuatorArray(parent_cn, id);
                //require(canUnlinkActuator(parent_cn, subindex), "CUA02");
            }
        }

        deleteSatellite(id, devindex, sa_tipo, parent_cn, subindex);

        return true;
    }

    //JAHALLA
    //TERMINAL - Eliminar un compute node y primero elimina todos sus satelites
    function destroyComputeNode(uint id) public returns(bool success) {

        //IMPORTANTE: desde GAMA ya se debe saber el tipo de dispositivo
        //y llamar a la función correcta para eliminarlo
        //puede ser esta o destroySatellite()

        //26:CN,12:S,14:S,16:A,69:A,36:CN,49:S,45:S,78:A,76:A,86:S,87:S,88:A
        //S:49,45|A:78,76

        //26:CN,12:S,14:S,16:A,69:A,86:S,88:A,87:S
        //S:|A:

        uint devindex = findIDInDeviceArray(id);
        //require(canDeleteDevice(devindex) && isComputeNode(id), "CDD+NCN01");
        deleteComputeNode(id, devindex);
        return true;
    }

    //JAHALLA
    //Borrar todos los sensores y actuadores
    function deleteAllSatellites() public returns(bool success) {

        //26:CN,12:S,14:S,16:A,69:A,36:CN
        //26 - S:12,14|A:16,69

        uint curr_id;
        uint curr_tipo;
        uint parent_cn;
        uint subindex;

        //puse los breaks para cuando i=0 porque
        //como i es uint, me da miedo que el i-- de hecho incremente la i al máximo
        //y entonces la condición de i>=0 del for siempre se cumpla...

        for(uint i=amount_devices-1; i>=0; i--) {

            curr_id   = getDevice(i);
            curr_tipo = readDeviceVariable(curr_id, TYPE);
            parent_cn = readDeviceVariable(curr_id, PARENT);

            if(curr_tipo==COMPUTE_NODE) {
                if(i==0) {break;}
                continue;
            }else if(curr_tipo==SENSOR) {
                subindex = findIDInSubSensorArray(parent_cn, curr_id);
            }else if(curr_tipo==ACTUATOR) {
                subindex = findIDInSubActuatorArray(parent_cn, curr_id);
            }

            //aquí dentro se hace el unlink, el zeroshift y se decrementan los contadores de dispositivos
            deleteSatellite(curr_id, i, curr_tipo, parent_cn, subindex);

            if(i==0) {break;}
        }

        return true;
    }

    //JAHALLA
    //TERMINAL - Inicializar el sistema completo
    function deleteAllDevices() public returns(bool success) {

        //require(knownDevicesExist(), "NKD04");

        //borrar primero todos los sensores y actuadores
        deleteAllSatellites();

        //en este punto asumimos que todos los devices que quedan son compute nodes
        //y que ninguno se va a tener que meter a borrar sus satélites
        while(amount_devices > 0) {
            //aquí dentro se hace el unlink, el zeroshift y se decrementan los contadores de dispositivos
            deleteComputeNode(getDevice(0), 0);
        }

        return true;
    }

    //JAHALLA
    //TERMINAL - Reemplazar un sensor o actuador
    function replaceDevice(uint sa_id) public returns(uint new_dev_id) {

        //require(deviceExists(sa_id) && isSensorOrActuator(sa_id), "DDE+NSN+NAC01");
        //require(newDeviceStillFits(), "DDF02");

        uint parent_cn = readDeviceVariable(sa_id, PARENT);
        uint tipo      = readDeviceVariable(sa_id, TYPE);
        uint subindex  = 0;

        if(parent_cn > DEFAULT_ID) {

            if(tipo==SENSOR) {
                //require(newSensorStillFitsCN(parent_cn),"SDF01");
                subindex = findIDInSubSensorArray(parent_cn, sa_id);
            }else if(tipo==ACTUATOR) {
                //require(newActuatorStillFitsCN(parent_cn),"ADF01");
                subindex = findIDInSubActuatorArray(parent_cn, sa_id);
            }
        }

        //si pasa las validaciones, llega a la función wrappeada

        //crear un device nuevo
        uint new_id = createDevice(tipo);

        //clonar la configuración del viejo en el nuevo
        cloneConfig(sa_id, new_id);

        //si el viejo tuviera padre, el nuevo también debe tenerlo
        if(parent_cn > DEFAULT_ID) {
            linkDeviceToComputeNode(new_id, parent_cn);
        }

        //borrar el viejo
        deleteSatellite(
            sa_id,
            findIDInDeviceArray(sa_id),
            tipo,
            parent_cn,
            subindex
        );

        return new_id;
    }
}

//eof
