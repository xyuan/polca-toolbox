--  Copyright (C) 2015 The IMDEA Software Institute 
-- 	            and the Technical University of Madrid

-- All rights reserved.
-- For additional copyright information see below.

-- This file is part of the polca-transformation-rules package

-- License: This work is licensed under the Creative Commons
-- Attribution-NonCommercial-NoDerivatives 4.0 International
-- License. To view a copy of this license, visit
-- http://creativecommons.org/licenses/by-nc-nd/4.0/ or send a letter
-- to Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
--
-- Main author: Salvador Tamarit
-- Please address questions, etc. to: <polca-project-madrid@software.imdea.org>



--{-# LANGUAGE DeriveDataTypeable, TemplateHaskell #-}

module PragmaPolcaLib where

import RulesLib

import Language.C
import Language.C.Data.Node
import Language.C.Data.Name
import Language.C.Data.Position
import Language.C.System.GCC   -- preprocessor used

import System.IO 

import Data.Generics
import Data.Char (isSpace)
import Data.List
import Data.List.Split
import Data.Either
import Data.Maybe
--import Data.Text (strip, unpack )

import Control.Lens


import qualified Text.Groom as Gr

import Debug.Trace


--TODO: Improve this. It is avoiding infinite loops when searching.
-- Represents the limit of pragmas per statement
pragma_limit_per_stmt = 20


parsePolcaAnn filename =
  do  
    --handle <- openFile input_file ReadMode
    contents <- readFile filename
    let linesFile = lines contents
    let numberedLines = zip [1..(length linesFile)] linesFile
    let pragmas = foldl readPolcaAnn [] numberedLines
    return pragmas


putStrLnCond True str = 
	putStrLn str
putStrLnCond False str = 
	return ()

readFileInfo verbose name = 
 	do 
 		let filename0 = name ++ ".c"
		(includes, rest) <- separateIncludes filename0
		-- putStrLn (show includes)
		let filename1 = name ++ "_temp.c"
		writeFile filename1 (concat (intersperse "\n" rest))
		ast0 <- parseMyFile filename1
		polcaAnn' <- parsePolcaAnn filename1
		--removeFile filename
		let (errors,polcaAnn) = errorsNclean  polcaAnn'
		putStrLnCond verbose ("AST successfully read from " ++ filename0 ++ " and stored in " ++ name ++ ".ast")
		let (ast1,_) = separateNodesLib filename1 ast0
		let linkedPolcaAnn_prev = linkPolcaAnn ast1 polcaAnn
		--putStrLn (show linkedPolcaAnn_prev)
		-- TODO: It should no remove them, instead it should fuse them
		--let linkedPolcaAnn = removeDuplicatePragmas linkedPolcaAnn_prev
		let linkedPolcaAnn = linkedPolcaAnn_prev
		--putStrLn (show linkedPolcaAnn)
		if errors /= [] 
		then error (unlines errors)
		else putStrLnCond verbose ("Pragmas polca successfully read from " ++ filename0)
		writeFile (name ++ ".ast") (Gr.groom ast1)
		return (ast1, linkedPolcaAnn,includes)

printStdLib includes = ""
 	-- case [include | include <- includes, (trim include) == "#include <stdlib.h>"] of 
 	-- 	[] ->
 	-- 		"#include <stdlib.h>\n"
 	-- 	_ ->
 	-- 		""	

writeFileWithPragmas nameFile state =
	writeFileWithPragmasInt nameFile state ""

writeFileWithPragmasInt nameFile state header = 
	do
		let strPrg = printWithPragmasInt prettyPragmas state
		writeFile nameFile (header ++ strPrg)

writeFileOnlyPolcaPragmas nameFile state =
	writeFileOnlyPolcaPragmasInt nameFile state ""

writeFileOnlyPolcaPragmasInt nameFile state header = 
	do
		let strPrg = printWithPragmasInt prettyPragmasPolca state
		writeFile nameFile (header ++ strPrg)

writeFileWithoutPragmas nameFile state =
	writeFileWithoutPragmasInt nameFile state ""

writeFileWithoutPragmasInt nameFile state header = 
	do
		let strPrg = printWithoutPragmas state
		writeFile nameFile (header ++ strPrg)

printWithoutPragmas  state = 
	let 
		allincludes = includes state
		(CTranslUnit defs _) = rebuildAst state
		strPrg = 
			concat 
				(map 
					(++"\n\n") 
					(map (prettyMyAST.(fmap (\(Ann nI _) -> nI))) defs))
	in 
		((unlines allincludes) ++ (printStdLib allincludes) ++ "\n\n" ++ strPrg)


printWithPragmas state = 
	printWithPragmasInt prettyPragmas state

printWithPragmasInt printPragmaFun state = 
	printWithPragmasAux printPragmaFun (\x -> (printStdLib x)) state	

printWithPragmasWithoutStdLib state = 
	printWithPragmasWithoutStdLibInt prettyPragmas state	

printWithPragmasWithoutStdLibInt printPragmaFun state = 
	printWithPragmasAux printPragmaFun (\_ -> "") state	

printWithPragmasAux printPragmaFun stdlib_gen state = 
	--prettyMyASTAnn (rebuildAst state))
	let 
		allincludes = includes state
		--pragmaInfo = pragmas state
		(CTranslUnit defs _) = rebuildAst state
		strPrg = 
			--""
			--concat (map (++"\n") (map (printWithPragmasDef pragmaInfo) defs))
			concat (map (++"\n\n") (map (printWithPragmasDef printPragmaFun) defs))
	in 
		((unlines allincludes) ++ (stdlib_gen allincludes) ++ "\n\n" ++ strPrg)
		
printWithPragmasDef printPragmaFun fun@(CFDefExt (CFunDef _ _ _ body@(CCompound _ _ _) (Ann _ nP))) = 
	let  
		--bodyStr = map printWithPragmasBlock body
		strPragmas = 
			printPragmaFun nP
		(CFDefExt (CFunDef a1 a2 a3 _ a4)) = 
			(fmap (\(Ann nI _) -> nI) fun)
		strFunWithoutPragmas = 
			prettyMyAST (CFDefExt (CFunDef a1 a2 a3 fillerStmt a4))
		bodyStr = 
			printWithPragmasStmt printPragmaFun body
		[pre, post] = 
			splitOn strFillerStmt strFunWithoutPragmas
		--bodyStr1 = drop 5 bodyStr0
		--bodyStr2 = reverse (drop 5 (reverse bodyStr1))
		--bodyStr = "{" ++ bodyStr2 ++ "}"
		strFun = 
			pre ++ bodyStr ++ post
	in 
		--(printUntilOpenCurvedBracket (lines (prettyMyASTAnn fun)))) ++ (concat (map (++"\n") bodyStr)) ++ "}\n"
		strFun
printWithPragmasDef printPragmaFun (decl@(CDeclExt (CDecl _ _ (Ann nI nP)))) = 
--printWithPragmasDef pragmaInfo (decl@(CDeclExt (CDecl _ _ nI))) = 
	let 
		strStmt = prettyMyASTAnn decl
		strPragmas = printPragmaFun nP
	in
		strPragmas ++ strStmt
		--case [pragmas | (namenode, pragmas) <- pragmaInfo, (geq namenode (fromMaybe (head newNameSupply) (nameOfNode nI)))] of 
		--	[] ->
		--		strStmt
		--	pragmasList ->
		--		(concat (map (\p -> "#pragma polca " ++ p ++ "\n") pragmasList)) ++ strStmt
printWithPragmasDef _ other = 
	prettyMyASTAnn other


prettyPragmas properties = 
	(prettyPragma properties)

prettyPragmasPolca properties = 
	(prettyPragmaPolca properties)

--emptyCurvedBracketsContent str = 
--	let 
--		preStr = takeWhile (\char -> \char /= '{') str
--		restStr = dropWhile (\char -> \char /= '{') str
--		reverseRest = (reverse restStr)
--		reversePostStr = takeWhile (\char -> \char /= '}') reverseRest
--		postStr = reverse reversePostStr
--	in 
--		case preStr of 
--			[] ->
--				Nothing 
--			_ ->
--				(Just (preStr, postStr))

fillerStmt = CReturn Nothing undefNode
strFillerStmt = "    return;"

printWithPragmasCompundBlocks printPragmaFun body = 
	case foldl (\acc line -> acc ++ line ++ "\n") "" (map (printWithPragmasBlock printPragmaFun) body) of 
		[] ->
			[] 
		other -> 
			init other

printWithPragmasStmt printPragmaFun stmt@(CCompound _ body _) = 
	let 
		strPragmas = 
			printPragmaFun (getAnnotation stmt)
		(CCompound a1 _ a2) = 
			(fmap (\(Ann nI _) -> nI) stmt)
		strStmtWithoutPragmas = 
			prettyMyAST (CCompound a1 [CBlockStmt fillerStmt] a2)
		bodyStr = printWithPragmasCompundBlocks printPragmaFun body
		[pre0,post] = 
			splitOn strFillerStmt strStmtWithoutPragmas
		pre = 
			reverse $ dropWhile (== ' ') (reverse pre0)
		strStmt = 
			pre ++ bodyStr ++ post
	in
		strPragmas ++ strStmt
printWithPragmasStmt printPragmaFun stmt@(CFor _ _ _ body _) = 
	let 
		strPragmas = 
			printPragmaFun (getAnnotation stmt)
		(CFor a1 a2 a3 _ a4) = 
			(fmap (\(Ann nI _) -> nI) stmt)
		strStmtWithoutPragmas = 
			prettyMyAST (CFor a1 a2 a3 fillerStmt a4)
		bodyStr = 
			printWithPragmasStmt printPragmaFun body
		[pre,post] = 
			splitOn strFillerStmt strStmtWithoutPragmas
		--pre = 
		--	reverse $ dropWhile (== ' ') (reverse pre0)
		strStmt = 
			pre ++ bodyStr ++ post
	in
		strPragmas ++ strStmt
printWithPragmasStmt printPragmaFun stmt@(CIf _ t Nothing _) =
	let 
		strPragmas = 
			printPragmaFun (getAnnotation stmt)
		(CIf a1 _ _ a2) = 
			(fmap (\(Ann nI _) -> nI) stmt)
		strStmtWithoutPragmas = 
			prettyMyAST (CIf a1 fillerStmt Nothing a2)
		tStr = 
			case t of 
				(CCompound _ body _) ->
					printWithPragmasCompundBlocks printPragmaFun body
				_ ->
					printWithPragmasStmt printPragmaFun t
		[pre,post] = 
			splitOn strFillerStmt strStmtWithoutPragmas
		--pre = 
		--	reverse $ dropWhile (== ' ') (reverse pre0)
		strStmt = 
			pre ++ tStr ++ post
	in
		strPragmas ++ strStmt
printWithPragmasStmt printPragmaFun stmt@(CIf _ t (Just e) _) =
	let 
		strPragmas = 
			printPragmaFun (getAnnotation stmt)
		(CIf a1 _ _ a2) = 
			(fmap (\(Ann nI _) -> nI) stmt)
		strStmtWithoutPragmas = 
			prettyMyAST (CIf a1 fillerStmt (Just fillerStmt) a2)
		tStr = 
			case t of 
				(CCompound _ body _) ->
					printWithPragmasCompundBlocks printPragmaFun body
				_ ->
					printWithPragmasStmt printPragmaFun t
		eStr = 
			case e of 
				(CCompound _ body _) ->
					printWithPragmasCompundBlocks printPragmaFun body
				_ ->
					printWithPragmasStmt printPragmaFun e
		[pret, postt_pree, poste] = 
			splitOn strFillerStmt strStmtWithoutPragmas
		--pret = 
		--	reverse $ dropWhile (== ' ') (reverse pret0)
		--postt_pree = 
		--	reverse $ dropWhile (== ' ') (reverse postt_pree0)
		strStmt = 
			pret ++ tStr ++ postt_pree ++ eStr ++ poste
	in
		strPragmas ++ strStmt
printWithPragmasStmt printPragmaFun stmt =
	let 
		strPragmas = 
			printPragmaFun (getAnnotation stmt) 
		cleanStmt = 
			(fmap (\(Ann nI _) -> nI) stmt)
		strStmt = 
			(prettyMyAST cleanStmt)
	in 
		strPragmas ++ strStmt

printWithPragmasBlockExt block = 
	printWithPragmasBlock prettyPragmas block

--printWithPragmasBlock _ = ""
printWithPragmasBlock printPragmaFun (CBlockStmt stmt) = 
	printWithPragmasStmt printPragmaFun stmt
	--let 
	--	-- TODO: If it is a block or a statement that can have a block, there should be printed usign this function
	--	strPragmas = printPragmaFun (getAnnotation stmt)
	--	cleanStmt = (fmap (\(Ann nI _) -> nI) stmt)
	--	strStmt = (prettyMyAST (CBlockStmt cleanStmt))
	--	--strStmt = (prettyMyAST (CBlockStmt stmt))
	--in
	--	strPragmas ++ strStmt
	--	--case [pragmas | (namenode, pragmas) <- pragmaInfo, (geq namenode (fromMaybe (head newNameSupply) (nameOfNode (nodeInfo stmt))))] of 
	--	--	[] ->
	--	--		strStmt
	--	--	pragmasList ->
	--	--		(concat (map (\p -> "#pragma polca " ++ p ++ "\n") pragmasList)) ++ strStmt
printWithPragmasBlock printPragmaFun (CBlockDecl decl@(CDecl _ _ (Ann _ nP))) = 
	let 
		strPragmas = printPragmaFun nP
		cleanStmt = (fmap (\(Ann nI _) -> nI) decl)
		strStmt = (prettyMyAST (CBlockDecl cleanStmt))
		--strStmt = (prettyMyAST (CBlockStmt stmt))
	in
		strPragmas ++ strStmt
printWithPragmasBlock _ other = 
	prettyMyASTAnn other


--removeAnn = fmap (\(Ann nI _) -> nI)

--getLastNode :: CTranslationUnit Annotation -> Int
--getLastNode (CTranslUnit _ (Ann nI _)) = 
getLastNode (CTranslUnit _ nI) = 
	case nameOfNode nI of 
		Just nameNode' -> 
			nameId nameNode'
		Nothing -> 
			nameId (head newNameSupply)


errorsNclean polcaAnn =
	--([(head l) | (-1,l) <- polcaAnn],
	([l | (-1,l) <- polcaAnn],
	 [i | i@(n,_) <- polcaAnn, n /= -1])

readPolcaAnn acc (numLine, line)
	| pragmasPolca /= [] =
		--case (validPragma (head parsedPolcaAnn)) of 
		--	True ->
				acc ++ [(numLine, pragmaPolca) | pragmaPolca <- pragmasPolca]
			--False ->
			--	acc ++ [(-1, ["Line " ++ (show numLine) ++ ": The following pragma polca is not recognized\n\t" ++ pragmaPolca])]
	| otherwise =
		acc
	where 
		pragmasPolca = 
			getPragmaPolca (trim line)
		--parsedPolcaAnn = 
		--	--words pragmaPolca
		--	pragmaPolca

getPragmaPolca line =
	let 
		polca_ann rest = 
			case 
				--trace 
				--(show $ stripPrefix "map " (trim rest)) $ 
				stripPrefix "map " (trim rest) 
			of
				Just args ->
					let
						[input,output] = words args  
					in 
						[rest, "input " ++ input, "output " ++ output, "iteration_independent"]
				Nothing ->
					[rest]
	in 
		case 
			--trace 
			--(show 
			--	(stripPrefix "#pragma polca " (trim line), 
			--	stripPrefix "#pragma stml " (trim line))
			--)
			(stripPrefix "#pragma polca " (trim line), 
			stripPrefix "#pragma stml " (trim line))
		of
			(Just rest,_) ->
			-- Is polca ann
				polca_ann rest 
			-- Is stml ann
			(_,Just rest) ->
				[rest]
			(Nothing,Nothing) -> 
				case 
					(stripPrefix "#pragma POLCA " (trim line), 
					stripPrefix "#pragma STML " (trim line)) 
				of
					(Just rest,_) ->
					-- Is polca ann
						polca_ann rest 
					-- Is stml ann
					(_,Just rest) ->
						[rest]
					(Nothing,Nothing) -> 
						[]


--validPragma("def") = True
--validPragma("mapStride") = True
--validPragma(_) = False
-- TODO: read only valid pragmas
validPragma(_) = True


--linkPolcaAnn :: CTranslUnit -> CTranslUnit
linkPolcaAnn ast polcaAnn = 
	let 
		lineName0 = (applyRulesGeneral buildLineName ast)
		lineName1 = groupLines lineName0
		lineName = sort lineName1
	in 
		linkAllPolcaAnn polcaAnn lineName


--[(linkOnePolcaAnn (line + 1) (line + 1) ast,ann) | (line,ann) <- polcaAnn]


groupLines ((line, name):lineName) =
	let 
		(sameLine, otherLine) = 
			partition (\(lineAst,_) -> lineAst == line ) lineName
	in 
		(line, last (name:[nameAst | (_,nameAst) <- sameLine])):(groupLines otherLine)
groupLines [] = 
	[]

linkAllPolcaAnn ((line,ann):polcaAnn) lineName = 
	case (filter (\(lineAst,_) -> lineAst >= line) lineName) of 
		[] ->
			[]
		((lineAst, nameAnn):otherLineName) ->
			let 
				--firstLineAst = 
				--	fst $ head newLineName
				--(sameLineName, otherLineName) = 
				--	partition (\(lineAst,_) -> lineAst == firstLineAst ) newLineName
				--(lineAstAnn, nameAnn) = last sameLineName
				(sameAnn, otherAnn) = 
					partition (\(lineAnn, _) -> lineAnn <= lineAst) polcaAnn 
				linkedToLineAst = 
					[(nameAnn, annList) | (_,annList) <- ((line,ann):sameAnn)]
			in
				linkedToLineAst ++ (linkAllPolcaAnn otherAnn otherLineName)
linkAllPolcaAnn [] _ = 
	[]

buildLineName  :: NodeInfo -> [(Int, Name)]
buildLineName n = 
	let position = posOfNode n
	in 
		if ((isNoPos position) || (isInternalPos position))
		then 
			[]
		else
			returnName (posRow position)
	where
		returnName line = 
			case nameOfNode n of 
				Just name -> [(line, name)]
				Nothing -> []

linkPolcaAnnAst ast polcaAnn = 
	[let pragmaAst = linkOnePolcaAnnAst (line + 1) ast
	 in (pragmaAst,ann,line,searchMinMaxLine pragmaAst) | (line,ann) <- polcaAnn]

-- TODO: Replace the way it is calculated as in linkPolcaAnnAst
linkOnePolcaAnnAst line ast 
	| line == pragma_limit_per_stmt = 
		(CBreak undefNode)
	| otherwise = 
		case result of 
			list@(_:_) -> 
				last list
			[] ->
				linkOnePolcaAnnAst (line + 1) ast
		where 
			result =
			 	applyRulesGeneral (lookForLineAst line) ast
				--everything (++) ( [] `mkQ` (lookForLineAst line)) ast


lookForLine :: Int -> NodeInfo -> [Name]
lookForLine line n = 
	let position = posOfNode n
	in 
		if ((isNoPos position) || (isInternalPos position))
		then []
		else
			if (posRow position) == line
			then returnName
			else []
	where
		returnName = 
			case nameOfNode n of 
				Just name -> [name]
				Nothing -> []

--lookForLineAst :: Int -> CNode -> [CNode]
lookForLineAst line n = 
	let 
		position = (posOfNode (nodeInfo n))
	in 
		if ((isNoPos position) || (isInternalPos position))
		then []
		else
			if (posRow position) == line
			then [n]
			else []

searchMinMaxLine ast = 
	let 
		listLines = 
			applyRulesGeneral storeLine ast
			--(everything (++) ( [] `mkQ` storeLine) ast)
	in 
		case listLines of 
			[] ->
				-1
			_ -> 
				minimum listLines

storeLine n = 
	let 
		position = posOfNode n
	in 
		if ((isNoPos position) || (isInternalPos position))
		then []
		else [(posRow position)]


removeDuplicatePragmas pragmas = 
	let
		names = nubBy (geq) [name | (name,_) <- pragmas] 
		namePragmas = [(name, correctPragmas [pragma | (name_, pragma) <- pragmas, name_ == name])  | name <- names ]
	in 
		concat [[(name, pragma) | pragma <- pragmasName] | (name, pragmasName) <- namePragmas]

trim :: String -> String
trim = f . f
   where f = reverse . dropWhile isSpace

parseMyFile :: FilePath -> IO CTranslUnit
parseMyFile input_file =
	  -- do parse_result <- parseCFile (newGCC "gcc") Nothing ["-fdirectives-only"] input_file
  --do parse_result <- parseCFilePre input_file
	do 
		parse_result <- parseCFile (newGCC "gcc") Nothing [] input_file
		case parse_result of
			Left parse_err -> error (show parse_err)
			Right ast      -> return ast

getAllNodes ((nodeId,ann):xs) ast = 
		result
	where
		nodesId = 
			applyRulesGeneral (lookForNode nodeId) ast
			--(everything (++) ( [] `mkQ` (lookForNode nodeId)) ast)
		node = head nodesId
		ntail = (getAllNodes xs ast)
		result = 
			--case trace ((show nodeId) ++ " " ++ (show nodesId)) nodesId of 
			case  nodesId of 
				[] -> ntail
				_ -> (( lines( prettyMyAST node)),ann):ntail

getAllNodes [] _ = 
	[]

--lookForNode nodeId n@(CBlockStmt _ nodeInfo) =
lookForNode nodeId n@(CFor _ _ _ _ nI) =
	--case trace ((show (nameOfNode nI)) ++ " " ++ (show nodeId)) (nameOfNode nI) of 
	case (nameOfNode nI) of 
		Just nodeId' 
			| nodeId' == nodeId -> [n]
			| otherwise -> []
		Nothing -> []
lookForNode _ _ = []

printMyAST :: CTranslUnit -> IO ()
printMyAST ctu = (print . pretty) ctu

separateNodesLib filename ast = 
	let
		(CTranslUnit decl nI) = ast
		(extDelcs,intDecl) = separateDeclaration filename decl
	in
		((CTranslUnit intDecl nI),extDelcs)

separateDeclaration filename ((decl@(CDeclExt (CDecl _ _ nI))):t) = 
	separateDeclarationGen filename decl nI t
separateDeclaration filename ((decl@(CFDefExt (CFunDef _ _ _ _ nI))):t) = 
	separateDeclarationGen filename decl nI t
--separateDeclaration filename (other:t) = 
--	let 
--		(extDelcs,intDecl) = (separateDeclaration filename t)
--	in 
--		trace (show other) (extDelcs,other:intDecl)
separateDeclaration _ [] = 
	([],[])
 
separateDeclarationGen filename decl nI t = 
	let 
		(extDelcs,intDecl) = (separateDeclaration filename t)
	in 
		case fileOfNode nI of 
			Nothing -> 
				(decl:extDelcs,intDecl)
			Just filenameNI -> 
				if filenameNI == filename 
				then
					(extDelcs,decl:intDecl)
				else 
					(decl:extDelcs,intDecl)

addExternalDefs ast2_ externalDefs = 
	let 
		(CTranslUnit decl nI) = ast2_
	in 
		(CTranslUnit (externalDefs++decl) nI)

separateIncludes filename = 
	do
		fullContent <- readFile filename
		let linesContent = lines fullContent
		let includesOthers = map separateIncludesLine linesContent
		return (lefts includesOthers, rights includesOthers)

separateIncludesLine line =
	case stripPrefix "#include " (trim line) of
		Just rest ->
			(Left line)
		Nothing -> 
			(Right line)

printUntilOpenCurvedBracket (line:tailLines)
	| elem '{' line  = 
		line ++ "\n"
	| otherwise = 
		line ++ "\n" ++ (printUntilOpenCurvedBracket tailLines)
printUntilOpenCurvedBracket [] = 
	"\n"

changeAnnAST :: [(Name, String)] -> CTranslUnitAnn -> CTranslUnitAnn
changeAnnAST  anns =
	everywhere (mkT (changeAnnAST_ anns ))

changeAnnAST_ :: [(Name, String)] -> NodeAnn -> NodeAnn
changeAnnAST_ anns ann@(Ann nI nP) = 
	case nameOfNode nI of 
		Nothing -> 
			ann
		(Just nameNI) ->
			let 
				pragmas = 
					[pragma | (nameAnn, pragma) <- anns, nameAnn == nameNI]
				initialProperties = 
					nP{_allPragmas = propertyInfoDefault{_value = Just pragmas}}
				--defaultAnn = [(head nP){specificInfo = AllPragmas pragmas}]
				--otherAnn = create_properties_node pragmas
				finalProperties = 
					modifyPropertiesNode pragmas initialProperties
			in 
				Ann nI finalProperties

modifyPropertiesNode (pragma:pragmas) properties
	| sideEffectsPrefix /= Nothing = 		
		updateAndContinue hasSideEffects sideEffectsPrefix readBoolean
	| readsPrefix /= Nothing =
		updateAndContinue readIn readsPrefix readStringList
	| writesPrefix /= Nothing =
		updateAndContinue writeIn writesPrefix readStringList
	| localSymbolsPrefix /= Nothing =
		updateAndContinue localSymbols localSymbolsPrefix readStringList
	| rangeInfoPrefix /= Nothing =
		updateAndContinue rangeInfo rangeInfoPrefix readStringListSpaced
	| isCanonicalPrefix /= Nothing =
		updateAndContinue isCanonical isCanonicalPrefix readBoolean
	| isPerfectNestPrefix /= Nothing =
		updateAndContinue isPerfectNest isPerfectNestPrefix readBoolean
	| hasLoopsPrefix /= Nothing =
		updateAndContinue hasLoops hasLoopsPrefix readBoolean
	| hasFunctionCallsPrefix /= Nothing =
		updateAndContinue hasFunctionCalls hasFunctionCallsPrefix readBoolean
	| hasControlFlowModifiersPrefix /= Nothing =
		updateAndContinue hasControlFlowModifiers hasControlFlowModifiersPrefix readBoolean
	| scalarDependencesPrefix /= Nothing =
		updateAndContinue scalarDependences scalarDependencesPrefix readStringList
	| polcaPrefix =
		updateAndContinuePolca (Just pragma) readStringListSpaced
	| otherwise =
		modifyPropertiesNode pragmas properties
	where 
		sideEffectsPrefix = stripGivenPrefix "side_effects" 
		readsPrefix = stripGivenPrefix "reads"
		writesPrefix = stripGivenPrefix "writes"
		localSymbolsPrefix = stripGivenPrefix "local_symbols" 
		rangeInfoPrefix = stripGivenPrefix "range_info" 
		isCanonicalPrefix = stripGivenPrefix "is_canonical" 
		isPerfectNestPrefix = stripGivenPrefix "is_perfect_nest" 
		hasLoopsPrefix = stripGivenPrefix "has_loops" 
		hasFunctionCallsPrefix = stripGivenPrefix "has_function_calls" 
		hasControlFlowModifiersPrefix = stripGivenPrefix "has_control_flow_modifiers" 
		scalarDependencesPrefix = stripGivenPrefix "scalar_dependences"
		polcaAnns = 
			["map", "init", "kernel", "def", "io", "type_size", "total_size", "input", "output", "iteration_independent"]
		polcaPrefix = 
			or [(stripGivenPrefix polcaAnn) /= Nothing | polcaAnn <- polcaAnns]
		stripGivenPrefix prefix = stripPrefix prefix (trim pragma)
		readStringList string = 
			let 
				(_:cleanedRest0) = trim (fromMaybe "" string)
				(_:cleanedRest1) = reverse cleanedRest0
				cleanedRest = reverse cleanedRest1
			in 
				case splitOn ", " cleanedRest of 
					[""] ->
						[] 
					other ->
						--map (\s -> PlainString s) other
						other
		readStringListSpaced string = 
			--map (\s -> PlainString s) (splitOn " " (trim (fromMaybe "" string)))
			splitOn " " (trim (fromMaybe "" string))
		readBoolean string = 
			case (trim (fromMaybe "error" string)) of 
				"true" -> 
					True
				"True" -> 
					True
				"false" ->
					False 
				"False" ->
					False 
		updateAndContinue field string readFunction = 
			let 
				newProperties = 
					(field.value .~ (Just (readFunction string))) properties
			in 
				modifyPropertiesNode pragmas newProperties
		updateAndContinuePolca string readFunction = 
			let 
				new_value = 
					case properties^.polcaPragmas.value of 
						Nothing -> 
							Just [(readFunction string)]
						Just previous_list ->
							Just ((readFunction string):previous_list)				
			in 
				modifyPropertiesNode pragmas ((polcaPragmas.value .~ new_value) properties)
modifyPropertiesNode [] properties = 
	properties


---------------------------------------------------------
-- OLD CODE
---------------------------------------------------------


--linkOnePolcaAnn startingLine line ast 
--	| (line - startingLine) == pragma_limit_per_stmt = 
--		Name {nameId = -1}
--	| otherwise =
--		case result of 
--			list@(_:_) -> 
--				last list
--			[] ->
--				linkOnePolcaAnn startingLine (line + 1) ast
--		where 
--			result = 
--				applyRulesGeneral  (lookForLine line) ast
--				--everything (++) ( [] `mkQ` (lookForLine line)) ast

--  do  
--    -- TODO: Improve this, file is read two times (here only to know the file lines length)
--    contents <- readFile filename
--    let linesFile = lines contents
--    let numberedLines = zip [1..(length linesFile)] linesFile
--    let pragmas = foldl readPolcaAnn [] numberedLines
--    return pragmas
--  where 
--  	assign_name line = 
--  		case applyRulesGeneral  (lookForLine line) ast of 
--			list@(_:_) -> 
--				last list
--			[] ->
--				Name {nameId = -1} 
  		


--assign_name line other = 
--	case applyRulesGeneral  (lookForLine line) ast of 
--		list@(_:_) -> 
--			last list
--		[] ->
--			Name {nameId = -1} 

--[(linkOnePolcaAnn (line + 1) (line + 1) ast,ann) | (line,ann) <- polcaAnn]

--writePragmas :: [String] -> [([String],[String])] -> [String] -> [String]
--writePragmas input codeAnn@((linesComp,polcaAnn):t) output =
--	if (length cleanedInput) /= (length linesComp)
--	then error ("\nNOT FOUND: " ++ (show linesComp) ++ "\n")  (writePragmas (output ++ input) t [])
--	else 
--		if (trimList cleanedInput) == (trimList linesComp)
--		then writePragmas (output ++ ["#pragma polca" ++ (foldl (\a s -> a ++ " " ++ s) "" polcaAnn)] ++ input) t []
--		else writePragmas (tail input) codeAnn (output ++ [(head input)])
--	where 
--		cleanedInput = cleanedCode input (length linesComp)
--		trimList = map trim 
--writePragmas input [] _ =
--	input

--cleanedCode _ 0 = 
--	[]
--cleanedCode (x:xs) n = 
--	if (getPragmaPolca x) == []
--	then x:(cleanedCode xs (n-1))
--	else cleanedCode xs n
--cleanedCode [] n = 
--	[]
