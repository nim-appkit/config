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

from algorithm import sorted
from os import nil

import alpha, omega
import values

import ../config

Suite "Config":
  
  Describe "Accessors":

    It "Should get/set values with get/setValue()":
      var c = newConfig()

      c.setValue("str", "str")
      c.get("str").getString().should equal "str"
      c.setValue("i", 10)
      c.get("i").getInt().should equal 10

    It "Should get/set NESTED values with get/SetValue()":
      var c = newConfig()

      c.setValue("a.b.c.d", "str")
      c.get("a.b.c.d").getString().should equal "str"

      c.setValue("a.b.c.e", 50)
      c.get("a.b.c.e").getInt().should equal 50

    It "Should report has() for nested keys":
      var c = newConfig()
      c.setValue("a.b.c.d.e", "str")
      c.has("a").should beTrue()
      c.has("a.b.c.e").should beFalse()
      c.has("a.b.c.d").should beTrue()

    It "Should set/get nested values with [](=)":
      var c = newConfig()
      c["x"] = "x"
      c["a.b.c.d"] = 22
      assert c["x"] == "x"
      assert c["a"]["b"]["c"]["d"] == 22

    It "Should set/get nested values with .(=)":
      var c = newConfig() 
      c.x = "x"
      c["a.b.c.d"] = 22

      assert c.x == "x"
      assert c.a.b.c.d == 22
      c.get("a.b.c.d").should equal 22

    It "Should get a nested config":
      var c = newConfig((a: 55, b: (c: 10, d: 1.11)))
      var cc = c.getConfig("b")

      cc.c.should equal 10


  Describe "Typed accessors":

    It "Should get string":
      var c = newConfig()
      c["a.b"] = "x"
      c.getString("a.b").should equal "x"

    It "Should get a string with a default val":
      var c = newConfig()
      c.getString("a", "default").should equal "default" 

    It "Should get an int":
      var c = newConfig()
      c["a.b"] = 22
      c.getInt("a.b").should equal 22

    It "Should get an int with a default val":
      var c = newConfig()
      c.getInt("a", 33).should equal 33

    It "Should get a float":
      var c = newConfig()
      c["a.b"] = 22.22
      c.getFloat("a.b").should equal 22.22

    It "Should get a float with a default val":
      var c = newConfig()
      c.getFloat("a", 33.33).should equal 33.33


  Describe "ENV loading":

    It "Should load settings from ENV":
      var c = newConfig((a: "test", b: 1, c: (x: false, y: 1.1)))

      os.putEnv("a", "newA")
      os.putEnv("b", "33")
      os.putEnv("c.x", "true")
      os.putEnv("c.y", "33.33")

      c.loadEnvVars()

      c.a.should equal "newA"
      c.b.should equal 33
      c.c.x.should equal true
      c.c.y.should equal 33.33

  Describe "JSON":

    It "Should build a config from json":
      var c = configFromJson("""{"s": "s", "i": 1, "f": 1.1, "nested": {"arr": [1, 2, 3]}}""" )
      sorted(c.getKeys(), cmp[string]).should equal(@["f", "i", "nested", "s"])

    It "Should build a config from a json file.":
      var tmpFile = os.joinPath(os.getTempDir(), "nim_utils_config_json_test.json")
      writeFile(tmpFile, """{"s": "s", "i": 1, "f": 1.1, "nested": {"arr": [1, 2, 3]}}""" )

      var c = configFromJsonFile(tmpFile)
      sorted(c.getKeys(), cmp[string]).should equal(@["f", "i", "nested", "s"])

    It "Should dump a config to json.":
      var tmpFile = os.joinPath(os.getTempDir(), "nim_config_json_test.json")
      var c = newConfig()
      c.s = "s"
      c.i = 1
      c.f = 1.1
      c.nested = @%(arr: @[1, 2, 3])

      c.writeJsonFile(tmpFile)
      var fileC = configFromJsonFile(tmpFile)

      sorted(c.getKeys(), cmp[string]).should equal(sorted(fileC.getKeys(), cmp[string]))

  Describe "YAML":
    It "Should build a config from yaml":
      var c = configFromYaml("s: String\ni: 5\nnested: {x: false}")
      c.s.should equal "String"
      c.i.should equal 5
      c.nested.x.should equal false

    It "Should build a config from a yaml file.":
      var tmpFile = os.joinPath(os.getTempDir(), "nim_config_yaml_test.json")
      writeFile(tmpFile, "s: String\ni: 5\nnested: {x: false}")

      var c = configFromYamlFile(tmpFile)
      c.s.should equal "String"
      c.i.should equal 5
      c.nested.x.should equal false
