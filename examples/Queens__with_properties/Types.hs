{-# LANGUAGE DeriveGeneric, DeriveAnyClass #-}

module Types where
import Test.QuickCheck hiding ((===))
import Debug.Hoed.Pure

data Board = B [Int] deriving (Eq, Show, Generic, Observable, ParEq)

instance Arbitrary Board where 
  arbitrary = do b <- genBoard; return (B b)

genBoard :: Gen [Int]
genBoard = sized $ \n ->
  do m <- choose (0,n)
     k <- choose (0,n)
     vectorOf k (genPos m)

genPos :: Int -> Gen Int  
genPos n | n < 1 = return 1
genPos n = elements [1..n]

data Configuration = Configuration Int Board
  deriving (Show,Eq, Generic, Observable, ParEq)