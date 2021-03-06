module CoreParser where

import Language
import BaseParser
import Control.Applicative
import Data.Char

parseProg :: Parser (CoreProgram)
parseProg = do
    p <- parseScDefn
    do symbol ";"
       ps     <- parseProg
       return (p:ps)
       <|> return [p]

--------------------------------------------------------------------------------

parseScDefn :: Parser (CoreScDef)
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
parseExpr3 = parseNonAssociativeOpsIn relops parseExpr4

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
    definitions     <- parseLetDefs
    symbol          "in"
    e               <- parseExpr
    return $ ELet mod definitions e

parseLetDefs :: Parser [CoreDef]
parseLetDefs = do
    vars <- semicolonList parseDef
    return vars

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
    symbol "\\"
    vars <- parseLambdaVars
    symbol "."
    body <- parseExpr
    return $ ELam vars body

parseLambdaVars :: Parser [Name]
parseLambdaVars = do 
    vars   <- some parseCoreVar
    return vars

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
    if var `elem` keywords
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

parseNonAssociativeOpsIn :: [String] -> Parser CoreExpr -> Parser CoreExpr
parseNonAssociativeOpsIn ops nextParser = do
    a <- nextParser
    do op <- symbols ops
       b  <- nextParser
       return $ EAp (EAp (EVar op) a) b
       <|> return a

parseArithmeticOperatorPair :: String -> String -> Parser CoreExpr -> Parser CoreExpr
parseArithmeticOperatorPair associativeOperator nonAssociativeOperator nextParser = do
    sub1 <- nextParser
    do symbol associativeOperator
       sub2 <- parseArithmeticOperatorPair associativeOperator   nonAssociativeOperator nextParser
       return $ EAp (EAp (EVar associativeOperator) sub1) sub2
       <|> do symbol nonAssociativeOperator
              sub2 <- nextParser
              return $ EAp (EAp (EVar nonAssociativeOperator) sub1) sub2
       <|> return sub1

applicationChain :: [CoreExpr] -> CoreExpr
applicationChain (x:[]) = x
applicationChain xs = EAp (applicationChain $ init xs) (last xs)
