-- A program with unexpected output.

import MyModule
import Debug.Hoed.Pure

-- main = quickcheck prop_idemSimplify
main = testOwp properties prop_idemSimplify (Mul (Const 1) (Const 2))
  where
  properties = [ Propositions [(BoolProposition,myModule,"prop_idemOne",[0])]      PropertiesOf "one" []
               , Propositions [(BoolProposition,myModule,"prop_idemZero",[0])]     PropertiesOf "zero" []
               , Propositions [(BoolProposition,myModule,"prop_idemSimplify",[0])] PropertiesOf "simplify" []
               ]
  myModule = Module "MyModule" "../examples/ExpressionSimplifier"
