module Main where

import Debug.Hoed.Pure
import Syntax
import Parser
import Interpreter
import Machine
import Compiler

main = runOwp properties $ do
  let prog = parse gcdSource
  putStrLn "interpreted:"
  print (obey prog)
  putStrLn "compiled:"
  print (exec (compile prog))
  where
  properties = [Propositions [(BoolProposition,modInterpreter,"prop_ifT",[1,0])] PropertiesOf "run" [modSyntax,modValue]
               ]
  modInterpreter = Module "Interpreter" "../examples/afp02Exercises/Compiler__with_properties/"
  modValue = Module "Value" "../examples/afp02Exercises/Compiler__with_properties/"
  modSyntax = Module "Syntax" "../examples/afp02Exercises/Compiler__with_properties/"

gcdSource :: String
gcdSource = "x := 148; y := 58;\nwhile ~(x=y) do\n  if x < y then y := y - x\n  else x := x - y\n  fi\nod;\nprint x\n"
