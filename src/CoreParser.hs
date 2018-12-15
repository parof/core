module CoreParser where

import Language
import BaseParser
import Control.Applicative
import Data.Char

-- parseProg :: Parser (Program Name)
-- parseProg = do p <- parseScDef
--                do character ';'
--                   ps <- parseProg
--                   return (p:ps)
--                <|> return [p]

-- parseScDef :: Parser (ScDef Name)
-- parseScDef = do v <- identifier
--                 pf <- many identifier
--                 char '='
--                 body <- parseExpr -- call to parseExpr
--                 return (v, pf, body)

keywords = [
    "let",
    "letrec",
    "in",
    "case",
    "of",
    "Pack"]

parseExpr :: Parser CoreExpr
parseExpr =  parseLet
         <|> parseLetRec
         <|> parseCase
         <|> parseAExpr -- should go last
         <|> empty

--------------------------------------------------------------------------------
--                                    Let
--------------------------------------------------------------------------------

parseLet :: Parser CoreExpr
parseLet = do
    symbol "let"         
    (definitions,e) <- parseLetBody
    return $ ELet nonRecursive definitions e

parseLetRec :: Parser CoreExpr
parseLetRec = do
    symbol "letrec"
    (definitions,e) <- parseLetBody
    return $ ELet recursive definitions e

parseLetBody :: Parser ([CoreDef], CoreExpr)
parseLetBody = do
    definitions <- semicolonList parseDef
    symbol "in"
    e <- parseExpr
    return (definitions, e)

parseDef :: Parser CoreDef
parseDef = do
    (EVar var) <- parseEVar
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
    vars <- many (do (EVar var) <- parseEVar
                     return var) 
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
parseEVar = do
    var <- identifier
    if elem var keywords
        -- variables should not be keywords
        then empty
        else return $ EVar var

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