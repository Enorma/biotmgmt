#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""Project Documentation

    Name: biotserver.py

    Bridge between GAMA and Ethereum
    for establishing a connection to and from each other.
    This requires some web3 provider (i.e. Ganache)
    which runs the BIoTMgmt smart contract.

    Author: Enrique Ortiz Macias,
    Author: Liliana Durán Polanco,
    Author: Francisco Emmanuel Alemán Elizalde
"""

from web3 import Web3, HTTPProvider
from _thread import * #de aquí sale start_new_thread
from html.entities import name2codepoint
from datetime import datetime
from textwrap import wrap
import xml.etree.ElementTree as ET
import subprocess
import socket
import string
import signal
import json
import sys
import os
import re

from cryptography.hazmat.backends import default_backend as crypto_default_backend
from cryptography.hazmat.primitives import serialization as crypto_serialization
from cryptography.hazmat.primitives.asymmetric import rsa

#redeploy contract on Ganache with:
#truffle migrate --reset --compile-all

#---------------------------------------------------------------------------------------------------
#--GLOBAL VARIABLES FOR ETH-------------------------------------------------------------------------

blockchain_address = "http://127.0.0.1:7545"
BIoTMgmt_json      = "build/contracts/BIoTMgmt.json"
logfile            = "logs/bridgelog.log"
web3               = Web3(HTTPProvider(blockchain_address))
addr               = None
abi_arr            = None
contract           = None

#---------------------------------------------------------------------------------------------------
#--GLOBAL VARIABLES FOR GAMA------------------------------------------------------------------------

ServerSocket = socket.socket()
threadcount  = 0
host         = "127.0.0.1"
port         = 9999
udpport      = 9877
msgbuffer    = ""
headerbanner = True

#---------------------------------------------------------------------------------------------------
#--SMART CONTRACT CONSTANTS-------------------------------------------------------------------------

ckeytoname = {
    0:   "DEFAULT_ID_OR_VALUE", #ID de un dispositivo que no existe o value de una key que no existe
    1:   "SENSOR",
    2:   "ACTUATOR",
    3:   "COMPUTE_NODE",
    10:  "LOW",                 #no es cero para no confundirse con un valor default
    11:  "HIGH",
    110: "AMOUNT_SENSORS",      #cantidad de sensores asociados al CN
    120: "AMOUNT_ACTUATORS",    #cantidad de actuadores asociados al CN
    130: "THRESHOLD",           #umbral para el valor reportado por sus sensores
    210: "LAST_READING",        #último valor reportado por el sensor
    310: "ACT_COMMAND",         #indica si el actuador debe trabajar (11) o no (10)
    410: "PARENT",              #id del CN al que está asociado
    510: "ID",                  #id unívoco del dispositivo
    520: "TYPE",                #tipo del dispositivo (S:1|A:2|CN:3)
    530: "PUBLIC_KEY",          #llave pública del dispositivo
    540: "PERMISSION",          #indica si el dispositivo tiene permiso de operar (11) o no (10)
    550: "ON_OFF_STATUS"        #indica si el dispositivo está encendido (11) o apagado (10)
}

ckeytonumber = {
    "DEFAULT_ID_OR_VALUE" : 0,   #ID de un dispositivo que no existe o value de una key que no existe
    "SENSOR"              : 1,
    "ACTUATOR"            : 2,
    "COMPUTE_NODE"        : 3,
    "LOW"                 : 10,  #no es cero para no confundirse con un valor default
    "HIGH"                : 11,
    "AMOUNT_SENSORS"      : 110, #cantidad de sensores asociados al CN
    "AMOUNT_ACTUATORS"    : 120, #cantidad de actuadores asociados al CN
    "THRESHOLD"           : 130, #umbral para el valor reportado por sus sensores
    "LAST_READING"        : 210, #último valor reportado por el sensor
    "ACT_COMMAND"         : 310, #indica si el actuador debe trabajar (11) o no (10)
    "PARENT"              : 410, #id del CN al que está asociado
    "ID"                  : 510, #id unívoco del dispositivo
    "TYPE"                : 520, #tipo del dispositivo (S:1|A:2|CN:3)
    "PUBLIC_KEY"          : 530, #llave pública del dispositivo
    "PERMISSION"          : 540, #indica si el dispositivo tiene permiso de operar (11) o no (10)
    "ON_OFF_STATUS"       : 550  #indica si el dispositivo está encendido (11) o apagado (10)
}

#---------------------------------------------------------------------------------------------------
#--FUNCTIONS FOR LOGGING----------------------------------------------------------------------------

def processReceipt(tr):

    global addr

    tr = str(tr)

    tr = tr.replace(" ", "")
    tr = tr.replace("'", '"')
    tr = tr.replace(")", "")
    tr = tr.replace("HexBytes(", "")
    tr = tr.replace("AttributeDict(", "")
    tr = tr.replace(":None,", ':"'+addr+'",')

    return tr
#processReceipt

def processFunctionList(fl):

    fl = str(fl)

    fl = fl.replace("uint256", "")
    fl = fl.replace(",,,,", "")
    fl = fl.replace(",,,", "")
    fl = fl.replace(",,", "")
    fl = fl.replace("(,)", "()")
    fl = fl.replace("Function ", "")
    fl = fl.replace("<", "")
    fl = fl.replace(">", "")

    return fl
#processFunctionList

def printAndLog(str_to_log):

    global logfile

    dt = datetime.now().strftime("%Y/%m/%d - %H:%M:%S")
    composite_str = dt+" - "+str_to_log

    with open(logfile, "a") as lf:
        lf.write("\n"+composite_str)
    #with

    print(composite_str)

    return
#printAndLog

def onlyLog(str_to_log):

    global logfile

    dt = datetime.now().strftime("%Y/%m/%d - %H:%M:%S")
    composite_str = dt+" - "+str_to_log

    with open(logfile, "a") as lf:
        lf.write("\n"+composite_str)
    #with

    return
#onlyLog

def logReceipt(str_to_log):

    global logfile

    with open(logfile, "a") as lf:
        lf.write(" TXN Receipt: "+str_to_log)
    #with

    return
#logReceipt

#---------------------------------------------------------------------------------------------------
#--ETH BRIDGE SETUP---------------------------------------------------------------------------------

def getContractAddress():

    bashCommand = "truffle networks"
    process     = subprocess.run(bashCommand.split(), stdout=subprocess.PIPE)
    output      = str(process.stdout)

    #limpiar el output
    output = output.replace("('*')", "")
    output = output.replace("*", "")
    output = output.replace("  :", "")
    output = output.replace(" :", "")
    output = output.replace("    ", " ")
    output = output.replace("   ", " ")
    output = output.replace("  ", " ")
    output = output.replace("\\n ", "\\n")
    output = output.replace("\\n\\n", "\\n")
    output = output.replace("\\n", "*")
    output = output.replace(": ", "*")
    output = output.replace("b\"", "")
    output = output.replace("\"", "")
    output = output.strip("*")
    #print(output) #descomentar para debuggear

    output_arr = output.split("*")
    #print(output) #descomentar para debuggear

    arr_idx = -1

    try:
        arr_idx = output_arr.index("BIoTMgmt")
        #print("BIoTMgmt index: "+str(arr_idx)) #descomentar para debuggear
    except(ValueError):
        print("ERROR. BIoTMgmt contract not deployed.\ntry using: truffle migrate --reset --compile-all")
        sys.exit(1)
    #try-except

    #print("BIoTMgmt address: "+output_arr[arr_idx+1]) #descomentar para debuggear

    return output_arr[arr_idx+1]
#getContractAddress

def getContractABI():

    global BIoTMgmt_json

    with open(BIoTMgmt_json) as file:
        contract_json = json.load(file) #Load contract info as JSON
        contract_abi  = contract_json['abi']
    #with

    return contract_abi
#getContractABI

def bridgeSetup():

    global addr
    global web3
    global abi_arr
    global contract

    printAndLog("Setting up bridge metadata...")

    addr = getContractAddress()
    onlyLog("BIoTMgmt contract address: "+addr) #descomentar para debuggear

    try:
        web3.eth.defaultAccount = web3.eth.accounts[0]
    except Exception as e:
        print("ERROR. Web3 provider not online. Is Ganache running?")
        sys.exit(1)
    #try-except
    onlyLog("Ganache default account: "+web3.eth.defaultAccount) #descomentar para debuggear

    abi_arr = getContractABI()
    onlyLog("ABI starts with: "+str(abi_arr[0])) #descomentar para debuggear

    #print() #descomentar para debuggear

    contract = web3.eth.contract(address=addr, abi=abi_arr)
    onlyLog("All functions: "+processFunctionList(contract.all_functions())) #descomentar para debuggear

    printAndLog("Bridge metadata set up sucessfully.")

    return
#bridgeSetup

#---------------------------------------------------------------------------------------------------
#--GAMA SERVER SETUP--------------------------------------------------------------------------------

def serverSetup():

    global ServerSocket
    global host
    global port

    try:
        ServerSocket.bind((host, port))
    except socket.error as e:
        print("ERROR setting up port: "+str(e))
        sys.exit(1)
    #try-except

    print("Listening on "+host+":"+str(port)+"...\n")
    ServerSocket.listen(5) #acepta tener 5 conexiones como máximo, atiende 1 y deja las 4 restantes en espera en una cola

    return
#serverSetup

#---------------------------------------------------------------------------------------------------
#--GAMA MESSAGE POSTPROCESSING----------------------------------------------------------------------

#Reemplazar un XML char-entity (&foo; / &#foo; / &#xfoo;)
def decode_xml_replacer(match):

    name = match.group(1)

    if(name.startswith("#")):
        return chr(int(name[1:], 16)) #convierte a int en base 16
    #if

    return chr(name2codepoint.get(name, "?")) #regresa el valor unicode de name, si no lo hay regresa "?"
#decode_xml_replacer

#Reemplazar todos los XML char-entities (&foo; / &#foo; / &#xfoo;)
def decode_xml_string(s):
    st = re.sub("&(.*?);", decode_xml_replacer, s)
    return st
#decode_xml_string

#Convertir el XML en un árbol
def clean_xml(message):

    #message = decode_xml_string(message) #reemplazar los char-entities

    try:
        tree = ET.ElementTree(ET.fromstring(message))
    except Exception as e:
        print(message)
        tree = "lol"
    #try-except

    return tree
#clean_xml

#Extraer un valor del XML
def get_contents(xml_tree, xml_path):

    root   = xml_tree.getroot()
    result = ""

    for form in root.findall(xml_path):
        result += form.text
    #for

    return result
#get_contents

#Convertir el XML recibido en sintácticamente válido
def prettyXML(xml_str):

    xml_str = xml_str.replace("\n", "")

    xml_str = xml_str.replace("@b@", "")
    xml_str = xml_str.replace("@r@", "")
    xml_str = xml_str.replace("@n@", "")

    xml_str = xml_str.replace("&amp;amp;", "&amp;")
    xml_str = xml_str.replace("&amp;apos;", "&apos;")
    xml_str = xml_str.replace("&amp;quot;", "&quot;")
    xml_str = xml_str.replace("&amp;lt;", "&lt;")
    xml_str = xml_str.replace("&amp;gt;", "&gt;")

    xml_str = xml_str.replace("&lt;", "<")
    xml_str = xml_str.replace("&gt;", ">")
    #xml_str = xml_str.replace("&amp;", "&")
    #xml_str = xml_str.replace("&apos;", "'")
    #xml_str = xml_str.replace("&quot;", '"')

    while "  " in xml_str:
        xml_str = xml_str.replace("  ", "")
    #while

    xml_str = xml_str.replace("> <", "><")
    xml_str = xml_str.replace("Message>Client", "Message>\nClient")

    xml_str = bufferXML(xml_str) #prevenir trabajar con el XML si llegó a medias

    return xml_str
#prettyXML

#Juntar pedazos del XML que llegaron a medias
def bufferXML(xml_str):

    global msgbuffer

    #si xml_str empieza y termina como debe, está bien formado y no falta hacerle nada
    if xml_str.startswith("ClientClient_") and xml_str.endswith("</ummisco.gama.network.common.CompositeGamaMessage>"):

        #el xml_str es un renglón bien formado, no hay que bufferear nada
        msgbuffer = ""
    else: #si xml_str no empieza y/o termina como debe, es que se cortó y luego va a llegar lo que le falta

        #bufferear lo que acaba de llegar
        msgbuffer += xml_str

        #por si con lo recién buffereado ya se completó el xml_str
        if msgbuffer.startswith("ClientClient_") and msgbuffer.endswith("</ummisco.gama.network.common.CompositeGamaMessage>"):
            xml_str = msgbuffer
            msgbuffer = "" #msgbuffer ya es un renglón bien formado, no hay que bufferear nada
        else:
            #el xml_str es un renglón mal formado, no imprimirlo por ahora
            xml_str = ""
        #if
    #if-else

    return xml_str
#bufferXML

#Quitar todo lo que el XML tenga a la izquierda
def removePrefixes(xml_list):

    for i in range(len(xml_list)):
        pre_idx = xml_list[i].find("<")
        xml_list[i] = xml_list[i][pre_idx:]
    #for

    return xml_list
#removePrefixes

#Ordenar los headers de conexión con GAMA
def prettyHeader(msg_str):

    msg_str = msg_str.replace("@b@", "")
    msg_str = msg_str.replace("@r@", "")
    msg_str = msg_str.replace("@n@", "")

    msg_str = msg_str.replace("\n", "")

    msg_str = msg_str.replace("0Client", "/Client")
    msg_str = msg_str.replace("0ALL", "/ALL")

    msg_str = msg_str.replace("/127.0.0.1:9999/127.0.0.1:9999/", "/127.0.0.1:9999/")

    msg_str = msg_str.replace("Client/127", "Client\n/127")
    msg_str = msg_str.replace("ALL/127", "ALL\n/127")

    return msg_str
#prettyHeader

#Determinar si una cadena tiene sólo caracteres no-significativos
def isDeadString(some_str):

    #espacios, tabs, brincos de línea y caracteres no imprimibles son no-significativos
    printable_non_whitespace = string.digits + string.ascii_letters + string.punctuation

    for c in printable_non_whitespace: #al menos 1 caracter significativo y el string es válido
        if c in some_str:
            return False
        #if
    #for

    return True
#isDeadString

#Remover caracteres no-significativos de un string
def removeTrash(got_str):

    checked = set()
    for c in got_str:
        if (c not in checked) and (c not in string.printable):
            got_str = got_str.replace(c, "")
        #if
        checked.add(c)
    #for

    return got_str
#removeTrash

#Genera un mapeo de devices según la lista de devices del ledger
def deviceStrToDict(dev_str):

    #dev_str viene en la forma:
    #"26:CN,12:S,14:S,16:A,69:A,36:CN,49:S,45:S,78:A,76:A,86:S,87:S,88:A"

    dev_dict = {
        "compute_nodes" : [],
        "sensors"       : [],
        "actuators"     : []
    }

    if len(dev_str)==0:
        return dev_dict
    #if

    dev_list = dev_str.split(",")
    dev_pair = []

    for d in dev_list:

        dev_pair = d.split(":")

        if dev_pair[1]=="CN":
            dev_dict["compute_nodes"].append(int(dev_pair[0]))
        elif dev_pair[1]=="S":
            dev_dict["sensors"].append(int(dev_pair[0]))
        elif dev_pair[1]=="A":
            dev_dict["actuators"].append(int(dev_pair[0]))
        #if-elif
    #for

    return dev_dict
#deviceStrToDict

#---------------------------------------------------------------------------------------------------
#--MGMT CALL WRAPPERS-------------------------------------------------------------------------------

def call_pingBackEnd():
    global contract
    res = contract.functions.pingBackEnd().call() #view returns(bool success)
    printAndLog("CALL to pingBackEnd() returned {0}.".format( str(res) ))
    return str(res)
#call_pingBackEnd

def call_getLatestID():
    global contract
    res = contract.functions.getLatestID().call() #view returns(uint256 latestid)
    printAndLog("CALL to getLatestID() returned {0}.".format( str(res) ))
    return str(res)
#call_getLatestID

def call_authDevice(device_id):

    #en cualquier momento se puede setear la llave PÚBLICA de un device usando txn_setPublicKey

    '''proceso de autenticación:
        GAMA llama a authProcess(), incluyendo como args el ID de un device y un mensaje
        el mensaje es un "handshake" firmado con la llave PRIVADA de ese device
        authProcess() llama a esta función para pedir a ETH la llave PÚBLICA de ese device
        authProcess() desencripta el handshake usando la llave PÚBLICA
        si sí se puede desencriptar, authProcess() llama a txn_grantPerms para ese device y retorna true
        si no, llama a txn_denyPerms para ese device y retorna false
    '''

    global contract
    res = contract.functions.authDevice(device_id).call() #view returns(uint256 devpubkey)
    printAndLog("CALL to authDevice({0}) returned {1}.".format( str(device_id), str(res) ))
    return str(res)
#call_authDevice

def call_readDeviceVariable(device_id, config_key):
    global contract
    res = contract.functions.readDeviceVariable(device_id, config_key).call() #view returns(uint256 configval)
    printAndLog("CALL to readDeviceVariable({0}, {1}) returned {2}.".format( str(device_id), str(config_key), str(res) ))
    return str(res)
#call_readDeviceVariable

def call_getDeviceInfo(device_id):
    global contract
    res = contract.functions.getDeviceInfo(device_id).call() #view returns(string memory devicedata)
    printAndLog("CALL to getDeviceInfo({0}) returned {1}.".format( str(device_id), str(res) ))
    return str(res)
#call_getDeviceInfo

def call_getSatellites(device_id):
    global contract
    res = contract.functions.getSatellites(device_id).call() #view returns(string memory satellites)
    printAndLog("CALL to getSatellites({0}) returned {1}.".format( str(device_id), str(res) ))
    return str(res)
#call_getSatellites

def call_getDevices():
    global contract
    res = contract.functions.getDevices().call() #view returns(string memory devicelist)
    printAndLog("CALL to getDevices() returned {0}.".format( str(res) ))
    return str(res)
#call_getDevices

def call_refreshAll():

    all_devs_str  = call_getDevices()

    if all_devs_str=="":
        return "&"
    #if

    all_devs_dict = deviceStrToDict(all_devs_str)

    dev_info     = ""
    all_dev_info = ""
    sat_str      = ""
    all_sat_str  = ""
    full_str     = ""

    for dev in (all_devs_dict["sensors"] + all_devs_dict["actuators"]):

        dev_info = call_getDeviceInfo(dev)
        if all_dev_info!="": all_dev_info += "%"
        all_dev_info += str(dev) + "?" + dev_info
    #for

    for dev in all_devs_dict["compute_nodes"]:

        dev_info = call_getDeviceInfo(dev)
        sat_str  = call_getSatellites(dev)

        if(all_dev_info != ""): all_dev_info += "%"
        if(all_sat_str  != ""): all_sat_str  += "%"

        all_dev_info += str(dev) + "?" + dev_info
        all_sat_str  += str(dev) + "?" + sat_str
    #for

    if all_sat_str=="":
        all_sat_str = "&"
    #if

    full_str = (all_devs_str + "*" + all_dev_info + "*" + all_sat_str)

    #el string tiene que ser más corto que 1024 chars, contando lo que se le va a prependar y appendar
    charlimit = 1024 - len("refreshAll/!!") #1011

    if len(full_str) > charlimit:
        full_list = wrap(full_str, charlimit) #divide en una lista de strings de max 1011 chars c/u
        return full_list
    else:
        return full_str
    #if-else
#call_refreshAll

def call_reportCommand(cn_id):
    global contract
    res = contract.functions.reportCommand(cn_id).call() #view returns(uint command)
    printAndLog("CALL to reportCommand({0}) returned {1}.".format( str(cn_id), str(res) ))
    return str(res)
#call_reportCommand

#---------------------------------------------------------------------------------------------------
#--MGMT TXN WRAPPERS--------------------------------------------------------------------------------

#con txn_hash.hex() tenemos el hash de la txn como string

def txn_setPublicKey(device_id, config_value): #followed by readDeviceVariable

    global web3
    global contract

    txn_hash     = contract.functions.writeDeviceVariable(device_id, ckeytonumber["PUBLIC_KEY"], config_value).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for writeDeviceVariable({0}, PUBLIC_KEY, {1}) successful.".format( str(device_id), str(config_value) ))
    logReceipt(json_receipt)

    res = contract.functions.readDeviceVariable(device_id, ckeytonumber["PUBLIC_KEY"]).call() #view returns(uint256 configval)
    printAndLog("CALL to readDeviceVariable({0}, PUBLIC_KEY) after txn_setPublicKey returned {1}.".format( str(device_id), str(res) ))

    return str(res)
#txn_setPublicKey

def txn_setThreshold(cn_id, config_value): #followed by readDeviceVariable

    global web3
    global contract

    txn_hash     = contract.functions.writeDeviceVariable(cn_id, ckeytonumber["THRESHOLD"], config_value).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for writeDeviceVariable({0}, THRESHOLD, {1}) successful.".format( str(cn_id), str(config_value) ))
    logReceipt(json_receipt)

    res = contract.functions.readDeviceVariable(cn_id, ckeytonumber["THRESHOLD"]).call() #view returns(uint256 configval)
    printAndLog("CALL to readDeviceVariable({0}, THRESHOLD) after txn_setThreshold returned {1}.".format( str(cn_id), str(res) ))

    return str(res)
#txn_setThreshold

def txn_writeDeviceVariable(device_id, config_key, config_value): #followed by readDeviceVariable

    global web3
    global contract

    txn_hash     = contract.functions.writeDeviceVariable(device_id, config_key, config_value).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for writeDeviceVariable({0}, {1}, {2}) successful.".format( str(device_id), str(config_key), str(config_value) ))
    logReceipt(json_receipt)

    res = contract.functions.readDeviceVariable(device_id, config_key).call() #view returns(uint256 configval)
    printAndLog("CALL to readDeviceVariable({0}, {1}) after txn_writeDeviceVariable returned {2}.".format( str(device_id), str(config_key), str(res) ))

    return str(res)
#txn_writeDeviceVariable

def txn_deleteDeviceVariable(device_id, config_key): #followed by readDeviceVariable

    global web3
    global contract

    txn_hash     = contract.functions.deleteDeviceVariable(device_id, config_key).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for deleteDeviceVariable({0}, {1}) successful.".format( str(device_id), str(config_key) ))
    logReceipt(json_receipt)

    res = contract.functions.readDeviceVariable(device_id, config_key).call() #view returns(uint256 configval)
    printAndLog("CALL to readDeviceVariable({0}, {1}) after txn_deleteDeviceVariable returned {2}.".format( str(device_id), str(config_key), str(res) ))

    return str(res)
#txn_deleteDeviceVariable

#(1xx) (default: 3)
def txn_addCNKey(config_key): #followed by nothing, user can check new key on a separate call

    global web3
    global contract

    txn_hash     = contract.functions.addCNKey(config_key).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for addCNKey({0}) successful.".format( str(config_key) ))
    logReceipt(json_receipt)

    return str(True)
#txn_addCNKey

#(2xx) (default: 1)
def txn_addSensorKey(config_key): #followed by nothing, user can check new key on a separate call

    global web3
    global contract

    txn_hash     = contract.functions.addSensorKey(config_key).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for addSensorKey({0}) successful.".format( str(config_key) ))
    logReceipt(json_receipt)

    return str(True)
#txn_addSensorKey

#(3xx) (default: 1)
def txn_addActuatorKey(config_key): #followed by nothing, user can check new key on a separate call

    global web3
    global contract

    txn_hash     = contract.functions.addActuatorKey(config_key).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for addActuatorKey({0}) successful.".format( str(config_key) ))
    logReceipt(json_receipt)

    return str(True)
#txn_addActuatorKey

#(4xx) (default: 1)
def txn_addSatelliteKey(config_key): #followed by nothing, user can check new key on a separate call

    global web3
    global contract

    txn_hash     = contract.functions.addSatelliteKey(config_key).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for addSatelliteKey({0}) successful.".format( str(config_key) ))
    logReceipt(json_receipt)

    return str(True)
#txn_addSatelliteKey

#(5xx) (default: 5)
def txn_addDeviceKey(config_key): #followed by nothing, user can check new key on a separate call

    global web3
    global contract

    txn_hash     = contract.functions.addDeviceKey(config_key).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for addDeviceKey({0}) successful.".format( str(config_key) ))
    logReceipt(json_receipt)

    return str(True)
#txn_addDeviceKey

def txn_grantPerms(device_id): #followed by readDeviceVariable

    global web3
    global contract

    txn_hash     = contract.functions.grantPerms(device_id).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for grantPerms({0}) successful.".format( str(device_id) ))
    logReceipt(json_receipt)

    res = contract.functions.readDeviceVariable(device_id, ckeytonumber["PERMISSION"]).call() #view returns(uint256 configval)
    printAndLog("CALL to readDeviceVariable({0}, PERMISSION) after txn_grantPerms returned {1}.".format( str(device_id), str(res) ))

    return str(res)
#txn_grantPerms

def txn_denyPerms(device_id): #followed by readDeviceVariable, user can check individual satellites' perms on separate calls

    global web3
    global contract

    txn_hash     = contract.functions.denyPerms(device_id).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for denyPerms({0}) successful.".format( str(device_id) ))
    logReceipt(json_receipt)

    res = contract.functions.readDeviceVariable(device_id, ckeytonumber["PERMISSION"]).call() #view returns(uint256 configval)
    printAndLog("CALL to readDeviceVariable({0}, PERMISSION) after txn_denyPerms returned {1}.".format( str(device_id), str(res) ))

    return str(res)
#txn_denyPerms

def txn_turnOnDevice(device_id): #followed by readDeviceVariable

    global web3
    global contract

    txn_hash     = contract.functions.turnOnDevice(device_id).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for turnOnDevice({0}) successful.".format( str(device_id) ))
    logReceipt(json_receipt)

    res = contract.functions.readDeviceVariable(device_id, ckeytonumber["ON_OFF_STATUS"]).call() #view returns(uint256 configval)
    printAndLog("CALL to readDeviceVariable({0}, ON_OFF_STATUS) after txn_turnOnDevice returned {1}.".format( str(device_id), str(res) ))

    return str(res)
#txn_turnOnDevice

def txn_turnOffDevice(device_id): #followed by readDeviceVariable, user can check individual satellites' statuses on separate calls

    global web3
    global contract

    txn_hash     = contract.functions.turnOffDevice(device_id).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for turnOffDevice({0}) successful.".format( str(device_id) ))
    logReceipt(json_receipt)

    res = contract.functions.readDeviceVariable(device_id, ckeytonumber["ON_OFF_STATUS"]).call() #view returns(uint256 configval)
    printAndLog("CALL to readDeviceVariable({0}, ON_OFF_STATUS) after txn_turnOffDevice returned {1}.".format( str(device_id), str(res) ))

    return str(res)
#txn_turnOffDevice

def txn_turnOnAllDevices(): #followed by nothing, user can check individual devices' statuses on separate calls

    global web3
    global contract

    txn_hash     = contract.functions.turnOnAllDevices().transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for turnOnAllDevices() successful.")
    logReceipt(json_receipt)

    return str(True)
#txn_turnOnAllDevices

def txn_turnOffAllDevices(): #followed by nothing, user can check individual devices' statuses on separate calls

    global web3
    global contract

    txn_hash     = contract.functions.turnOffAllDevices().transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for turnOffAllDevices() successful.")
    logReceipt(json_receipt)

    return str(True)
#txn_turnOffAllDevices

def txn_applyDefaultConfig(device_id, tipo): #followed by getDeviceInfo

    global web3
    global contract

    txn_hash     = contract.functions.applyDefaultConfig(device_id, tipo).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for applyDefaultConfig({0}, {1}) successful.".format( str(device_id), str(tipo) ))
    logReceipt(json_receipt)

    res = contract.functions.getDeviceInfo(device_id).call() #view returns(string memory devicedata)
    printAndLog("CALL to getDeviceInfo({0}) returned {1}.".format( str(device_id), str(res) ))

    return str(res)
#txn_applyDefaultConfig

def txn_uploadReading(cn_id, sa_id, reading): #followed by readDeviceVariable

    global web3
    global contract

    txn_hash     = contract.functions.uploadReading(cn_id, sa_id, reading).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for uploadReading({0}, {1}, {2}) successful.".format( str(cn_id), str(sa_id), str(reading) ))
    logReceipt(json_receipt)

    res = contract.functions.readDeviceVariable(sa_id, ckeytonumber["LAST_READING"]).call() #view returns(uint256 configval)
    printAndLog("CALL to readDeviceVariable({0}, LAST_READING) after txn_uploadReading returned {1}.".format( str(sa_id), str(res) ))

    return str(res)
#txn_uploadReading

def txn_evalSensors(cn_id): #followed by reportCommand

    global web3
    global contract

    txn_hash     = contract.functions.evalSensors(cn_id).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for evalSensors({0}) successful.".format( str(cn_id) ))
    logReceipt(json_receipt)

    res = contract.functions.reportCommand(cn_id).call() #view returns(uint command)
    printAndLog("CALL to reportCommand({0}) returned {1}.".format( str(cn_id), str(res) ))

    return str(res)
#txn_evalSensors

def txn_unlinkSubDevice(sa_id): #followed by readDeviceVariable, user can check CN's satellite list on a separate call

    global web3
    global contract

    txn_hash     = contract.functions.unlinkSubDevice(sa_id).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for unlinkSubDevice({0}) successful.".format( str(sa_id) ))
    logReceipt(json_receipt)

    res = contract.functions.readDeviceVariable(sa_id, ckeytonumber["PARENT"]).call() #view returns(uint256 configval)
    printAndLog("CALL to readDeviceVariable({0}, PARENT) after txn_unlinkSubDevice returned {1}.".format( str(sa_id), str(res) ))

    return str(res)
#txn_unlinkSubDevice

def txn_linkDeviceToComputeNode(sa_id, new_cn): #followed by readDeviceVariable, user can check CN's satellite list on a separate call

    global web3
    global contract

    txn_hash     = contract.functions.linkDeviceToComputeNode(sa_id, new_cn).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for linkDeviceToComputeNode({0}, {1}) successful.".format( str(sa_id), str(new_cn) ))
    logReceipt(json_receipt)

    res = contract.functions.readDeviceVariable(sa_id, ckeytonumber["PARENT"]).call() #view returns(uint256 configval)
    printAndLog("CALL to readDeviceVariable({0}, PARENT) after txn_linkDeviceToComputeNode returned {1}.".format( str(sa_id), str(res) ))

    return str(res)
#txn_linkDeviceToComputeNode

def txn_createDevice(tipo): #followed by getLatestID

    global web3
    global contract

    txn_hash     = contract.functions.createDevice(tipo).transact() #returns(uint256 new_dev_id)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for createDevice({0}) successful.".format( ckeytoname[tipo] ))
    logReceipt(json_receipt)

    res = contract.functions.getLatestID().call() #view returns(uint256 latestid)
    printAndLog("CALL to getLatestID() after txn_createDevice returned {0}.".format( str(res) ))

    return str(res)
#txn_createDevice

def txn_destroySatellite(device_id): #followed by getDevices

    global web3
    global contract

    txn_hash     = contract.functions.destroySatellite(device_id).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for destroySatellite({0}) successful.".format( str(device_id) ))
    logReceipt(json_receipt)

    res = contract.functions.getDevices().call() #view returns(string memory devicelist)
    printAndLog("CALL to getDevices() after txn_destroySatellite returned {0}.".format( str(res) ))

    return str(res)
#txn_destroySatellite

def txn_destroyComputeNode(device_id): #followed by getDevices

    global web3
    global contract

    txn_hash     = contract.functions.destroyComputeNode(device_id).transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for destroyComputeNode({0}) successful.".format( str(device_id) ))
    logReceipt(json_receipt)

    res = contract.functions.getDevices().call() #view returns(string memory devicelist)
    printAndLog("CALL to getDevices() after txn_destroyComputeNode returned {0}.".format( str(res) ))

    return str(res)
#txn_destroyComputeNode

def txn_deleteAllDevices(): #followed by getDevices

    global web3
    global contract

    txn_hash     = contract.functions.deleteAllDevices().transact() #returns(bool success)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for deleteAllDevices() successful.")
    logReceipt(json_receipt)

    res = contract.functions.getDevices().call() #view returns(string memory devicelist)
    printAndLog("CALL to getDevices() after txn_deleteAllDevices returned {0}.".format( str(res) ))

    return str(res)
#txn_deleteAllDevices

def txn_replaceDevice(sa_id): #followed by getLatestID

    global web3
    global contract

    txn_hash     = contract.functions.replaceDevice(sa_id).transact() #returns(uint256 new_dev_id)
    txn_receipt  = web3.eth.wait_for_transaction_receipt(txn_hash)
    json_receipt = processReceipt(txn_receipt)

    printAndLog("TXN for replaceDevice({0}) successful.".format( str(sa_id) ))
    logReceipt(json_receipt)

    res = contract.functions.getLatestID().call() #view returns(uint256 latestid)
    printAndLog("CALL to getLatestID() after txn_replaceDevice returned {0}.".format( str(res) ))

    return str(res)
#txn_replaceDevice

#---------------------------------------------------------------------------------------------------
#--LEDGER DATA POSTPROCESSING-----------------------------------------------------------------------

def getSatelliteLists(s_str):

    #input is like: "S:12,14|A:16,69"

    s_half    = s_str[2:].split("|A:")

    sensors   = s_half[0].split(",") #["12", "14"]
    actuators = s_half[1].split(",") #["16", "69"]

    for i in range(len(sensors)):
        sensors[i] = int(sensors[i]) #all elements of the list become integers
    #for

    for i in range(len(actuators)):
        actuators[i] = int(actuators[i]) #all elements of the list become integers
    #for

    return(sensors, actuators)
#getSatelliteLists

#PENDIENTE
def setDeviceKeys(device_id):

    key = rsa.generate_private_key(
        backend=crypto_default_backend(),
        public_exponent=65537,
        key_size=2048
    )

    private_key = key.private_bytes(
        crypto_serialization.Encoding.PEM,
        crypto_serialization.PrivateFormat.PKCS8,
        crypto_serialization.NoEncryption()
    )

    public_key = key.public_key().public_bytes(
        crypto_serialization.Encoding.OpenSSH,
        crypto_serialization.PublicFormat.OpenSSH
    )

    datastr = "handshake"

    #lee estos para firmar un mensaje con la private key:
    #https://cryptography.io/en/latest/hazmat/primitives/asymmetric/rsa/#cryptography.hazmat.primitives.asymmetric.padding.AsymmetricPadding
    #https://cryptography.io/en/latest/hazmat/primitives/cryptographic-hashes/#cryptography.hazmat.primitives.hashes.HashAlgorithm
    #https://cryptography.io/en/latest/hazmat/primitives/asymmetric/rsa/#cryptography.hazmat.primitives.asymmetric.rsa.RSAPrivateKey.sign

    #lee este para desencriptar el mensaje:
    #https://cryptography.io/en/latest/hazmat/primitives/asymmetric/rsa/#cryptography.hazmat.primitives.asymmetric.rsa.RSAPrivateKey.decrypt

    print("public_key: "+str(public_key))
    return
#setDeviceKeys

#PENDIENTE
def authProcess(device_id, devkey):

    #en cualquier momento se puede setear la llave PÚBLICA de un device usando txn_setPublicKey

    '''proceso de autenticación:
        GAMA llama a esta función, incluyendo como args el ID de un device y un mensaje
        el mensaje es un "handshake" firmado con la llave PRIVADA de ese device
        desde aquí llamamos a call_authDevice() para pedir a ETH la llave PÚBLICA de ese device
        aquí desencriptamos el handshake usando la llave PÚBLICA
        si sí se puede desencriptar, llamamos a txn_grantPerms() para ese device y retornamos true
        si no, llamamos a txn_denyPerms() para ese device y retornamos false
    '''

    return
#authProcess

#---------------------------------------------------------------------------------------------------
#--SELECCIONAR FUNCIÓN DE ETH-----------------------------------------------------------------------

#si retorna None es que no corrió nada en ETH
def forwardFunction(argstr):

    #argstr está en el formato:
    #<function_name>/<arg1>/.../<argn>

    retval = ""
    arglist = argstr.split("/")

    for i in range(1, len(arglist)):
        try:
            arglist[i] = int(arglist[i])
        except Exception as e:
            print("Function arguments are wrong: "+str(e))
            return None
        #try-except
    #for

    if arglist[0]=="refreshAll" and len(arglist)==1: #CUSTOM CALL
        retval = call_refreshAll()
    elif arglist[0]=="reportCommand" and len(arglist)==2: #CALL: cn_id
        retval = call_reportCommand(arglist[1])
    elif arglist[0]=="pingBackEnd" and len(arglist)==1: #CALL
        retval = call_pingBackEnd()
    elif arglist[0]=="getLatestID" and len(arglist)==1: #CALL
        retval = call_getLatestID()
    elif arglist[0]=="getDevices" and len(arglist)==1: #CALL
        retval = call_getDevices()
    elif arglist[0]=="authDevice" and len(arglist)==2: #CALL: device_id
        retval = call_authDevice(arglist[1])
    elif arglist[0]=="getSatellites" and len(arglist)==2: #CALL: device_id
        retval = call_getSatellites(arglist[1])
    elif arglist[0]=="getDeviceInfo" and len(arglist)==2: #CALL: device_id
        retval = call_getDeviceInfo(arglist[1])
    elif arglist[0]=="readDeviceVariable" and len(arglist)==3: #CALL: device_id / config_key
        retval = call_readDeviceVariable(arglist[1], arglist[2])
    elif arglist[0]=="turnOnAllDevices" and len(arglist)==1: #TXN
        retval = txn_turnOnAllDevices()
    elif arglist[0]=="turnOffAllDevices" and len(arglist)==1: #TXN
        retval = txn_turnOffAllDevices()
    elif arglist[0]=="deleteAllDevices" and len(arglist)==1: #TXN
        retval = txn_deleteAllDevices()
    elif arglist[0]=="addCNKey" and len(arglist)==2: #TXN: config_key
        retval = txn_addCNKey(arglist[1])
    elif arglist[0]=="addSensorKey" and len(arglist)==2: #TXN: config_key
        retval = txn_addSensorKey(arglist[1])
    elif arglist[0]=="addActuatorKey" and len(arglist)==2: #TXN: config_key
        retval = txn_addActuatorKey(arglist[1])
    elif arglist[0]=="addSatelliteKey" and len(arglist)==2: #TXN: config_key
        retval = txn_addSatelliteKey(arglist[1])
    elif arglist[0]=="addDeviceKey" and len(arglist)==2: #TXN: config_key
        retval = txn_addDeviceKey(arglist[1])
    elif arglist[0]=="createDevice" and len(arglist)==2: #TXN: tipo
        retval = txn_createDevice(arglist[1])
    elif arglist[0]=="destroySatellite" and len(arglist)==2: #TXN: device_id
        retval = txn_destroySatellite(arglist[1])
    elif arglist[0]=="destroyComputeNode" and len(arglist)==2: #TXN: device_id
        retval = txn_destroyComputeNode(arglist[1])
    elif arglist[0]=="grantPerms" and len(arglist)==2: #TXN: device_id
        retval = txn_grantPerms(arglist[1])
    elif arglist[0]=="denyPerms" and len(arglist)==2: #TXN: device_id
        retval = txn_denyPerms(arglist[1])
    elif arglist[0]=="turnOnDevice" and len(arglist)==2: #TXN: device_id
        retval = txn_turnOnDevice(arglist[1])
    elif arglist[0]=="turnOffDevice" and len(arglist)==2: #TXN: device_id
        retval = txn_turnOffDevice(arglist[1])
    elif arglist[0]=="replaceDevice" and len(arglist)==2: #TXN: sa_id
        retval = txn_replaceDevice(arglist[1])
    elif arglist[0]=="unlinkSubDevice" and len(arglist)==2: #TXN: sa_id
        retval = txn_unlinkSubDevice(arglist[1])
    elif arglist[0]=="setPublicKey" and len(arglist)==3: #TXN: device_id / config_value
        retval = txn_setPublicKey(arglist[1], arglist[2])
    elif arglist[0]=="setThreshold" and len(arglist)==3: #TXN: cn_id / config_value
        retval = txn_setThreshold(arglist[1], arglist[2])
    elif arglist[0]=="deleteDeviceVariable" and len(arglist)==3: #TXN: device_id / config_key
        retval = txn_deleteDeviceVariable(arglist[1], arglist[2])
    elif arglist[0]=="applyDefaultConfig" and len(arglist)==3: #TXN: device_id / tipo
        retval = txn_applyDefaultConfig(arglist[1], arglist[2])
    elif arglist[0]=="linkDeviceToComputeNode" and len(arglist)==3: #TXN: sa_id / new_cn
        retval = txn_linkDeviceToComputeNode(arglist[1], arglist[2])
    elif arglist[0]=="writeDeviceVariable" and len(arglist)==4: #TXN: device_id / config_key / config_value
        retval = txn_writeDeviceVariable(arglist[1], arglist[2], arglist[3])
    elif arglist[0]=="uploadReading" and len(arglist)==4: #TXN: cn_id / sa_id / reading
        retval = txn_uploadReading(arglist[1], arglist[2], arglist[3])
    elif arglist[0]=="evalSensors" and len(arglist)==2: #TXN: cn_id
        retval = txn_evalSensors(arglist[1])
    else:
        print("Function name and/or arguments are wrong")
        return None
    #if-elif-else

    if type(retval) == list:
        for i in range(len(retval)-1):
            retval[i] += "!!"
        #for
        retval[-1] += "!"
    else:
        retval = str(retval)+"!" #mensaje normal en forma de string
    #if-else

    return retval
#forwardFunction

#---------------------------------------------------------------------------------------------------
#--RECIBIR Y ENVIAR MENSAJES------------------------------------------------------------------------

#UDP se usa sólo para los response
def send_udp_message(msgFromClient):

    global host
    global udpport

    #msgFromClient = "Hello UDP Server" #descomentar para debuggear
    #bufferSize    = 1024 #no se usa....

    serverAddressPort = (host, udpport)
    bytesToSend       = str.encode(msgFromClient, "utf-8")

    # Create a UDP socket at client side
    UDPClientSocket = socket.socket(family=socket.AF_INET, type=socket.SOCK_DGRAM)

    # Send to server using created UDP socket
    UDPClientSocket.sendto(bytesToSend, serverAddressPort)

    return
#send_udp_message

#Comunicación con GAMA
def threaded_client(connection, addr, tcount):

    global headerbanner

    connection.send(str.encode("Welcome to the Server...")) #esto aparece del lado del cliente, debe no tener newlines

    while True:

        data = connection.recv(2048)
        msg  = data.decode("utf-8")
        msg  = removeTrash(msg) #remover caracteres no imprimibles

        if "CompositeGamaMessage" in msg: #es el XML

            msg = prettyXML(msg)

            if msg=="":
                continue
            #if

            xml_list = msg.split("\n")
            xml_list = removePrefixes(xml_list)

            #print("I got "+str(len(xml_list))+" XMLs!") #descomentar para debuggear
            for x in xml_list:

                #Decode request
                xml_tree = clean_xml(x) #único uso de clean_xml, decode_xml_string y decode_xml_replacer

                #Read request
                content   = get_contents(xml_tree, "./contents/string") #aquí viene el comando que debemos forwardear a ETH
                client_id = get_contents(xml_tree, "./receivers/agentReference/attributeValue/index/int") #aquí viene el ID del agente que mandó el mensaje
                print("\nGAMA message received and processed!\nFrom thread #"+tcount+" @ address "+addr+"\nMessage: "+str(content))

                #-------------------------------------------------------------------
                #AQUÍ LEEMOS CONTENT, QUE DEBE TENER ALGÚN COMANDO Y ARGS PARA ETH
                #MANDAMOS LLAMAR A LA FUNCIÓN CORRESPONDIENTE DE ETH
                #Y CAPTURAMOS LA RESPUESTA QUE RECIBAMOS DE ETH
                #-------------------------------------------------------------------

                #retval = "foo" #descomentar para debuggear
                retval = forwardFunction(content)

                if retval is None:
                    continue
                elif type(retval) == list: #Send response as several UDP messages

                    retval[0] = content+"/"+retval[0]
                    print("\nSending fragmented response back to GAMA\nResponse: ", end="")

                    for fragment in retval:
                        print(fragment, end="")
                        send_udp_message(fragment) #enviar respuesta de regreso a GAMA
                    #for

                    print()
                else:
                    #Send response once
                    reply = content+"/"+str(retval)
                    print("\nSending response back to GAMA\nResponse: "+reply)
                    send_udp_message(reply) #enviar respuesta de regreso a GAMA
                #if-elif
            #for
        elif ("@b@" in msg) or ("@r@" in msg) or ("@n@" in msg): #es el header
            #print("I got the header!") #descomentar para debuggear
            msg = prettyHeader(msg)
            if headerbanner:
                print("\nConnection headers received:")
                headerbanner = False
            #if
            print(msg)
        elif isDeadString(msg): #es una cadena vacía (señal de que se cerró la conexión)
            print("\n-------------------------------------------------")
            print("Connection closed from client side. Exiting...")
            print("-------------------------------------------------\n")
            os.kill(os.getpid(), signal.SIGINT)
        else:

            #prevenir que el proceso se interrumpa si el mensaje trae newlines
            msg = msg.replace("\n", "")
            msg = msg.strip()

            #imprimir mensaje del lado del server
            if msg!="":
                print("\nNON-GAMA message received and processed!\nFrom thread #"+tcount+" @ address "+addr+"\nMessage: "+msg)
            else:
                print("\n--------------------------------------------------------------")
                print("Thread #"+tcount+" on address "+addr+" closed at client side.")
                print("--------------------------------------------------------------\n")
                os.kill(os.getpid(), signal.SIGINT)
            #if

            retval = forwardFunction(msg)

            if retval is None:
                continue
            #if

            #Send response
            reply = msg+"/"+str(retval)
            print("\nSending response back to CLIENT\nResponse: "+reply)

            #imprimir mensaje del lado del cliente, debe no tener newlines
            #connection.send(str.encode(" Your message is: "+msg)) #por alguna razón no jala
        #if-elif-else

        #print(msg) #descomentar para debuggear

        if not data:
            break #única forma de salir del while, es cuando ya no hay más data que leer
        #if

        #connection.send(str.encode("\n")) #enviar un newline indica el final de la respuesta, después de enviarlo no se puede enviar nada más
    #while

    connection.close()

    return
#threaded_client

#---------------------------------------------------------------------------------------------------
#--INICIAR UN THREAD PARA CADA MENSAJE ENTRANTE-----------------------------------------------------

def serverListen():

    global ServerSocket
    global threadcount

    while True:

        threadcount += 1
        Client, address = ServerSocket.accept()
        addrport = address[0]+":"+str(address[1])
        identifier = start_new_thread(threaded_client, (Client, addrport, str(threadcount))) #sale de la librería _thread, ejecuta threaded_client con el arg Client en un thread separado
        print("\nNew connection!\nThread #"+str(threadcount)+"\nAddress:    "+addrport+"\nIdentifier: "+str(identifier))
    #while

    return
#serverListen

def main():

    global ServerSocket

    print()
    printAndLog("-------------------------------------------------------------------------------")

    bridgeSetup()

    #aquí hardcodea funciones de ETH para testear...

    serverSetup()
    serverListen()
    ServerSocket.close()

    return 0
#main

if __name__ == '__main__':
    #para poder foldear...
    main()
#if

#eof
