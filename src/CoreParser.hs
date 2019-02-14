module CoreParser where

import Language
import BaseParser
import Control.Applicative
import Data.Char

parseProg :: Parser (Program Name)
parseProg = do
    p <- parseScDefn
    do symbol ";"
       ps     <- parseProg
       return (p:ps)
       <|> return [p]

--------------------------------------------------------------------------------

parseScDefn :: Parser (ScDef Name)
parseScDefn = do fun        <- parseCoreVar
                 parameters <- parseVarList
                 char       '='
                 body       <- parseExpr
                 return (fun, parameters, body)

--------------------------------------------------------------------------------

parseExpr :: Parser CoreExpr
parseExpr =  parseLet
         <|> parseLetRec
         <|> parseCase
         <|> parseLambda
         <|> parseExpr1
         
parseExpr1 :: Parser CoreExpr
parseExpr1 = parseRightAssociativeOperator "|" parseExpr2

parseExpr2 :: Parser CoreExpr
parseExpr2 = parseRightAssociativeOperator "&" parseExpr3

parseExpr3 :: Parser CoreExpr
parseExpr3 = parseNonAssociativeOpIn relops parseExpr4

parseExpr4 :: Parser CoreExpr
parseExpr4 = parseArithmeticOperatorPair "+" "-" parseExpr5

parseExpr5 :: Parser CoreExpr
parseExpr5 = parseArithmeticOperatorPair "*" "/" parseExpr6

parseExpr6 :: Parser CoreExpr
parseExpr6 = fmap applicationChain (some parseAExpr)

--------------------------------------------------------------------------------
--                                 Let & LetRec
--------------------------------------------------------------------------------

parseLet :: Parser CoreExpr
parseLet = parseLetGeneralized "let" NonRecursive

parseLetRec :: Parser CoreExpr
parseLetRec = parseLetGeneralized "letrec" Recursive

parseLetGeneralized :: String -> IsRec -> Parser CoreExpr
parseLetGeneralized symbolString mod = do
    symbol          symbolString
    (definitions,e) <- parseLetBody
    return $ ELet mod definitions e

parseLetBody :: Parser ([CoreDef], CoreExpr)
parseLetBody = do
    definitions <- semicolonList parseDef
    symbol      "in"
    e           <- parseExpr
    return (definitions, e)

parseDef :: Parser CoreDef
parseDef = do
    var <- parseCoreVar
    symbol "="
    exp <- parseExpr
    return (var, exp)

--------------------------------------------------------------------------------
--                                    Case
--------------------------------------------------------------------------------

parseCase :: Parser CoreExpr
parseCase = do
    symbol "case"
    e      <- parseExpr
    symbol "of"
    cases  <- semicolonList parseAlt
    return $ ECase e cases

parseAlt :: Parser CoreAlt
parseAlt = do
    (n,vars) <- parseCaseHead
    body     <- parseExpr
    return (n, vars, body)

parseCaseHead :: Parser (Int, [Name])
parseCaseHead = do 
    n      <- parseCaseId
    vars   <- parseVarList
    symbol "->"
    return (n, vars)

parseCaseId :: Parser Int
parseCaseId = do 
    symbol "<"
    n      <- natural
    symbol ">"
    return n
    
parseVarList :: Parser [Name]
parseVarList = do
    vars <- many parseCoreVar 
    return vars

--------------------------------------------------------------------------------
--                                   Lambda
--------------------------------------------------------------------------------

parseLambda :: Parser CoreExpr
parseLambda = do
    vars <- parseLambdaHead
    body <- parseExpr
    return $ ELam vars body

parseLambdaHead :: Parser [Name]
parseLambdaHead = do 
    symbol "\\"
    vars   <- parseVarNonEmptyList
    symbol "."
    return vars

parseVarNonEmptyList :: Parser [Name]
parseVarNonEmptyList = do 
    v1 <- parseCoreVar
    others <- parseVarList
    return (v1:others)

--------------------------------------------------------------------------------
--                                    AEXpr
--------------------------------------------------------------------------------

parseAExpr :: Parser CoreExpr
parseAExpr =  parseEVar
          <|> parseENum
          <|> parseConstructor
          <|> parseAExprPar

parseEVar :: Parser CoreExpr
parseEVar = do v <- parseCoreVar
               return $ EVar v

parseCoreVar :: Parser String
-- this means that is a var and it's not a core language keyword 
parseCoreVar = do
    var <- identifier
    if elem var keywords
        -- variables should not be keywords
        then empty
        else return var

parseENum :: Parser CoreExpr
parseENum = do
    n <- integer 
    return $ ENum n

parseConstructor :: Parser CoreExpr
parseConstructor = do
    symbol "Pack{"
    n1     <- integer
    symbol ","
    n2     <- integer
    symbol "}"
    return $ EConstr n1 n2

parseAExprPar :: Parser CoreExpr
parseAExprPar = do 
    openPar
    e <- parseExpr
    closedPar
    return e

--------------------------------------------------------------------------------
--                                Aux functions
--------------------------------------------------------------------------------

parseRightAssociativeOperator :: String -> Parser CoreExpr -> Parser CoreExpr
parseRightAssociativeOperator op nextParser = do
    a <- nextParser
    do symbol op
       b <- parseRightAssociativeOperator op nextParser
       return $ EAp (EAp (EVar op) a) b
       <|> return a

parseNonAssociativeOpIn :: [String] -> Parser CoreExpr -> Parser CoreExpr
parseNonAssociativeOpIn ops nextParser = do
    a <- nextParser
    do op <- symbols ops
       b  <- nextParser
       return $ EAp (EAp (EVar op) a) b
       <|> return a

parseArithmeticOperatorPair :: String -> String -> Parser CoreExpr -> Parser CoreExpr
parseArithmeticOperatorPair repeatableOperator nonRepeatableOperator nextParser =  
    do sub1 <- nextParser 
       symbol repeatableOperator
       sub2 <- parseArithmeticOperatorPair repeatableOperator nonRepeatableOperator nextParser
       return $ EAp (EAp (EVar repeatableOperator) sub1) sub2
       <|> do sub1 <- nextParser 
              symbol nonRepeatableOperator
              sub2 <- nextParser
              return $ EAp (EAp (EVar nonRepeatableOperator) sub1) sub2
       <|> nextParser

applicationChain :: [CoreExpr] -> CoreExpr
applicationChain (x:[]) = x
applicationChain xs = EAp (applicationChain $ init xs) (last xs)
