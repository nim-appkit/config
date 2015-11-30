###############################################################################
##                                                                           ##
##                               nim-config                                  ##
##                                                                           ##
##   (c) Christoph Herzog <chris@theduke.at> 2015                            ##
##                                                                           ##
##   This project is under the MIT license.                                  ##
##   Check LICENSE.txt for details.                                          ##
##                                                                           ##
###############################################################################

from strutils import contains, format
from json import nil
import tables
from sequtils import nil
import os

import values
from yaml import nil

from utils/strings import nil

type ConfigError* = object of Exception
  discard

proc newConfigError(msg: string): ref ConfigError =
  newException(ConfigError, msg)

###########
# Config. #
###########

type Config* = ref object of values.ValueRef
  # A config object used for application configuration.
  # 
  # Provides many convenience accesors to access (nested) configuration data 
  # and options for loading configuration from YAML, JSON, or ini files.

  discard

#################
# Constructors. #
#################

proc newConfig*(): Config =
  # Construct a new empty config.

  result = Config(kind: valMap)
  result.setMapTable(initTable[string, ValueRef]())

proc newConfig*(val: ValueRef): Config =
  # Build a new Config based on a Value map.

  if not val.isMap():
    raise newException(ValueError, "Value must be a map")

  var val = val.copy()
  
  result = newConfig() 
  result.setMapTable(val.getMapTable())

proc newConfig*(data: tuple): Config =
  # Build a new config based on a tuple.

  newConfig(toValueRef(data))

proc copy*(c: Config): Config =
  new(result)
  deepCopy(result, c)

proc merge*(a, b: Config): Config =
  newConfig(ValueRef(a).merge(ValueRef(b)))

######################
# Getters / setters. #
######################

proc setValue*[T](c: Config, key: string, val: T) =
  # Set a config value.

  var key = key
  var map = cast[ValueRef](c)
  while key.contains('.'):
    let (left, right) = strings.lsplit(key, ".")

    if not c.hasKey(left):
      map[left] = newValueMap()

    key = right
    map = map[left]
  map[key] = val

proc get*(c: Config, key: string, default: ValueRef): ValueRef =
  # Retrieve a raw values.Value config key.
  # 
  # If the key is not found, the given default is returned.

  var map = ValueRef(c)
  var key = key
  while key.contains('.'):
    var (left, right) = strings.lsplit(key, ".")
    if not map.hasKey(left):
      return default
    map = map[left]
    key = right

  result = if map.hasKey(key): map[key] else: default

proc get*[T](c: Config, key: string, default: T): ValueRef =
  # Retrieve a raw values.Value config key.
  # 
  # If the key is not found, the given default is returned.
  
  c.get(key, toValueRef(default))


proc get*(c: Config, key: string): ValueRef {.raises: [Exception, KeyError, ValueError].} =
  # Retrieve a raw values.Value config key.
  # 
  # If the key is not found, a KeyError is raised.
  result = c.get(key, nil)
  if result == nil:
    raise newException(KeyError, "Config key $1 not found".format(key))

proc `[]`*(c: Config, key: string not nil): ValueRef =
  c.get(key)

proc `[]=`*[T](c: Config, key: string, val: T) =
  c.setValue(key, val)

proc has*(c: Config, key: string): bool =
  # Checks if the config has a certain config key.

  c.get(key, nil) != nil

proc getConfig*(c: Config, key: string): Config =
  # Retrieve a nested map as a Config object.
  # Key must exist, and must be a map.

  var val = c.get(key)
  if not val.isMap():
    raise newException(ValueError, "Key $1 is not a map, but $2".format(key, val.kind))
  result = newConfig(val)

proc getString*(c: Config, key: string not nil, default: string not nil): string =
  # Retrieve a string config value.
  # 
  # If the key is not found, the default value is returned.
  # If the config key is not of type string, a ValueError is raised.
  
  let val = c.get(key, nil)
  if val == nil:
    return default
  if not val.isString():
    raise newException(ValueError, "Key $1 is not a string, but '$2'".format(key, val.kind))
  result = val.getString()

proc getString*(c: Config, key: string not nil): string =
  # Retrieve a string config value.
  # 
  # If the key is not found, a KeyError is raised.
  # If the config key is not of type string, a ValueError is raised.

  let val = c.get(key)
  if not val.isString():
    raise newException(ValueError, "Key $1 is not a string, but '$2'".format(key, val.kind))
  result = val.getString()

proc getInt*(c: Config, key: string not nil, default: int): BiggestInt =
  # Retrieve an int config value.
  # 
  # If the key is not found, the default value is returned.
  # If the config key is not of type int, a ValueError is raised.
  
  let val = c.get(key, nil)
  if val == nil:
    return default
  if not val.isInt():
    raise newException(ValueError, "Key $1 is not an int, but '$2'".format(key, val.kind)) 
  result = val.getInt()

proc getInt*(c: Config, key: string not nil): BiggestInt =
  # Retrieve an int config value.
  # 
  # If the key is not found, a KeyError is raised.
  # If the config key is not of type int, a ValueError is raised.
  
  let val = c.get(key)
  if not val.isInt():
    raise newException(ValueError, "Key $1 is not an int, but '$2'".format(key, val.kind)) 
  result = val.getInt()

proc getFloat*(c: Config, key: string not nil, default: float): float =
  # Retrieve a float config value.
  # 
  # If the key is not found, the default value is returned.
  # If the config key is not of type float, a ValueError is raised.
  
  let val = c.get(key, nil)
  if val == nil:
    return default
  if not val.isFloat():
    raise newException(ValueError, "Key $1 is not a float, but '$2'".format(key, val.kind))
  result = val.getFloat()

proc getFloat*(c: Config, key: string not nil): float =
  # Retrieve a float config value.
  # 
  # If the key is not found, a KeyError is raised.
  # If the config key is not of type string, a ValueError is raised.
  
  let val = c.get(key)
  if not val.isFloat():
    raise newException(ValueError, "Key $1 is not an int, but '$2'".format(key, val.kind)) 
  result = val.getFloat()

#############
# Env vars. #
#############

proc loadEnvVars*(c: Config) =
  for rawKey, rawVal in os.envPairs():
    var key = string(rawKey)
    var val = string(rawVal)
    if c.has(key):
      var kind = c.get(key).kind
      try:
        c[key] = convertString(val, kind)
      except:
        raise newConfigError("Could not convert ENV variable '$1' to $2: $3".format(key, kind, getCurrentExceptionMsg()))


#########
# JSON. #
#########

proc configFromJson*(jsonContent: string): Config {.raises: [ValueError, json.JsonParsingError, Exception].} = 
  # Load configuration from a json string.
  var data = values.fromJson(jsonContent)
  result = newConfig(data)

proc configFromJsonFile*(path: string): Config {.raises: [IOError, ValueError, json.JsonParsingError, Exception].} =
  # Load configuration from a JSON file.

  result = configFromJson(readFile(path))

proc writeJsonFile*(c: Config, path: string) =
  # Writes the config data to a file as json.

  writeFile(path, c.toJson())

#########
# YAML. #
#########

proc configFromYaml*(yamlContent: string): Config {.raises: [ValueError, json.JsonParsingError, Exception].} = 
  # Load configuration from a yaml string.

  var data = yaml.parseYaml(yamlContent)
  result = newConfig(data)

proc configFromYamlFile*(path: string): Config {.raises: [IOError, ValueError, json.JsonParsingError, Exception].} =
  # Load configuration from a JSON file.

  var data = yaml.parseYamlFile(path)
  result = newConfig(data)

proc dumpYamlFile(c: Config, path: string) =
  # Writes the config data to a file as json.

  raise newConfigError("dumpYamlFile() not implemented yet")

