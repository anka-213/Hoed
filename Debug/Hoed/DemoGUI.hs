-- This file is part of the Haskell debugger Hoed.
--
-- Copyright (c) Maarten Faddegon, 2014

module Debug.Hoed.DemoGUI
where

import Prelude hiding(Right)
import Debug.Hoed.Render
import Data.Graph.Libgraph
import qualified Graphics.UI.Threepenny as UI
import Graphics.UI.Threepenny (startGUI,defaultConfig,tpPort,tpStatic
                              , Window, UI, (#), (#+), (#.), string, on
                              )
import System.Process(system)
import Data.IORef
import Data.List(intersperse)

--------------------------------------------------------------------------------

preorder :: CompGraph -> [Vertex]
preorder = getPreorder . getDfs

showStmt :: UI.Element -> IORef [Vertex] -> IORef Int -> UI ()
showStmt e filteredVerticesRef currentVertexRef = do 
  mv <- UI.liftIO $ lookupCurrentVertex currentVertexRef filteredVerticesRef
  let s = case mv of
                Nothing  -> "Select vertex above to show details."
                (Just v) -> showCompStmts v
  UI.element e # UI.set UI.text s
  return ()

data Filter = ShowAll | ShowSucc | ShowPred

demoGUI :: [(String,String)] -> IORef CompGraph -> Window -> UI ()
demoGUI sliceDict treeRef window
  = do return window # UI.set UI.title "Hoed debugging session"
       UI.addStyleSheet window "debug.css"

       -- Get a list of vertices from the computation graph
       tree <- UI.liftIO $ readIORef treeRef
       let ns = filter (not . isRoot) (preorder tree)

       -- Shared memory
       filteredVerticesRef <- UI.liftIO $ newIORef ns
       currentVertexRef    <- UI.liftIO $ newIORef (0 :: Int)

       -- Draw the computation graph
       img  <- UI.img 
       redraw img treeRef (Just $ head ns)
       img' <- UI.center #+ [UI.element img]

       -- Field to show computation statement(s) of current vertex
       compStmt <- UI.pre

       -- Menu to select which statement to show
       menu <- UI.select
       showStmt compStmt filteredVerticesRef currentVertexRef
       updateMenu menu treeRef currentVertexRef filteredVerticesRef
       let selectVertex' = selectVertex compStmt filteredVerticesRef currentVertexRef                                           $ redrawWith img treeRef
       on UI.selectionChange menu selectVertex'

       -- Buttons for the various filters
       filterTxt   <- UI.span   # UI.set UI.text "Filters: "
       showAllBut  <- UI.button # UI.set UI.text "Show all"
       showSuccBut <- UI.button # UI.set UI.text "Show successors"
       showPredBut <- UI.button # UI.set UI.text "Show predecessors"
       filters     <- UI.div #+ (map return [filterTxt, showAllBut, showSuccBut, showPredBut])
       let onClickFilter' = onClickFilter menu treeRef currentVertexRef filteredVerticesRef
                                          selectVertex'
       onClickFilter' showAllBut  ShowAll
       onClickFilter' showSuccBut ShowSucc
       onClickFilter' showPredBut ShowPred

       -- Status
       status <- UI.span
       updateStatus status treeRef 

       -- Buttons to judge the current statement
       right <- UI.button # UI.set UI.text "right"
       wrong <- UI.button # UI.set UI.text "wrong"
       let onJudge = onClick status menu img treeRef 
                             currentVertexRef filteredVerticesRef
       onJudge right Right
       onJudge wrong Wrong

       -- Populate the main screen
       hr <- UI.hr
       UI.getBody window #+ (map UI.element [filters, menu, right, wrong, status
                                            , compStmt, hr,img'])
       return ()

updateMenu :: UI.Element -> IORef CompGraph
              -> IORef Int -> IORef [Vertex] -> UI ()
updateMenu menu treeRef currentVertexRef filteredVerticesRef = do
       g  <- UI.liftIO $ readIORef treeRef
       i  <- UI.liftIO $ readIORef currentVertexRef
       ns <- UI.liftIO $ readIORef filteredVerticesRef
       let fs = faultyVertices g
       ops  <- mapM (\s->UI.option # UI.set UI.text s)
                                $ if ns == [] then ["No matches found"]
                                  else map (summarizeVertex fs) ns
       (UI.element menu) # UI.set UI.children []
       UI.element menu #+ (map UI.element ops)
       (UI.element menu) # UI.set UI.selection (Just i)
       return ()

vertexFilter :: Filter -> CompGraph -> Vertex -> [Vertex]
vertexFilter f g cv = filter (not . isRoot) $ case f of 
  ShowAll  -> preorder g
  ShowSucc -> succs g cv
  ShowPred -> preds g cv

onClick :: UI.Element -> UI.Element -> UI.Element 
           -> IORef CompGraph -> IORef Int -> IORef [Vertex]
           -> UI.Element -> Judgement-> UI ()
onClick status menu img treeRef currentVertexRef filteredVerticesRef b j = do
  on UI.click b $ \_ -> do
        (Just v) <- UI.liftIO $ lookupCurrentVertex currentVertexRef filteredVerticesRef
        updateTree img treeRef (Just v) (\tree -> markNode tree v j)
        updateMenu menu treeRef currentVertexRef filteredVerticesRef
        updateStatus status treeRef

lookupCurrentVertex :: IORef Int -> IORef [Vertex] -> IO (Maybe Vertex)
lookupCurrentVertex currentVertexRef filteredVerticesRef = do
  i <- readIORef currentVertexRef
  m <- readIORef filteredVerticesRef
  return $ if i < length m then Just (m !! i) else Nothing

-- onSelectVertex :: UI.Element -> UI.Element -> IORef [Vertex] -> IORef Int 
--                   -> (IORef [Vertex] -> IORef Int -> UI ()) -> UI ()
-- onSelectVertex menu compStmt filteredVerticesRef currentVertexRef myRedraw = do
--   on UI.selectionChange menu $ \mi -> case mi of
--         Just i  -> do UI.liftIO $ writeIORef currentVertexRef i
--                       showStmt compStmt filteredVerticesRef currentVertexRef
--                       myRedraw filteredVerticesRef currentVertexRef 
--                       return ()
--         Nothing -> return ()

selectVertex :: UI.Element -> IORef [Vertex] -> IORef Int  
        -> (IORef [Vertex] -> IORef Int -> UI ()) -> Maybe Int -> UI ()
selectVertex compStmt filteredVerticesRef currentVertexRef myRedraw mi = case mi of
        Just i  -> do UI.liftIO $ writeIORef currentVertexRef i
                      showStmt compStmt filteredVerticesRef currentVertexRef
                      myRedraw filteredVerticesRef currentVertexRef 
                      return ()
        Nothing -> return ()



onClickFilter :: UI.Element -> IORef CompGraph -> IORef Int -> IORef [Vertex] 
                  -> (Maybe Int -> UI ()) -> UI.Element -> Filter -> UI ()
onClickFilter menu treeRef currentVertexRef filteredVerticesRef selectVertex' e fil = do
  on UI.click e $ \_ -> do
    mcv <- UI.liftIO $ lookupCurrentVertex currentVertexRef filteredVerticesRef
    g <- UI.liftIO $ readIORef treeRef
    let cv = case mcv of (Just v) -> v
                         Nothing  -> head . (filter $ not . isRoot) . preorder $ g
        applyFilter f = do UI.liftIO $ writeIORef filteredVerticesRef (vertexFilter f g cv)
                           UI.liftIO $ writeIORef currentVertexRef 0
    applyFilter fil
    updateMenu menu treeRef currentVertexRef filteredVerticesRef
    selectVertex' (Just 0)

-- MF TODO: We may need to reconsider how Vertex is defined,
-- and how we determine equality. I think it could happen that
-- two vertices with equal equation but different stacks/relations
-- are now both changed.
markNode :: CompGraph -> Vertex -> Judgement -> CompGraph
markNode g v s = mapGraph f g
  where f Root = Root
        f v'   = if v' === v then v{status=s} else v'

        (===) :: Vertex -> Vertex -> Bool
        v1 === v2 = (equations v1) == (equations v2)

data MaxStringLength = ShorterThan Int | Unlimited

shorten :: MaxStringLength -> String -> String
shorten Unlimited s = s
shorten (ShorterThan l) s
          | length s < l = s
          | l > 3        = take (l - 3) s ++ "..."
          | otherwise    = take l s

-- MF TODO: Maybe we should do something smart with witespace substitution here?
noNewlines :: String -> String
noNewlines = filter (/= '\n')

showCompStmts :: Vertex -> String
showCompStmts = commas . map show . equations

summarizeVertex :: [Vertex] -> Vertex -> String
summarizeVertex fs v = shorten (ShorterThan 27) (noNewlines $ showCompStmts v) ++ s
  where s = if v `elem` fs then " !!" else case status v of
              Unassessed     -> " ??"
              Wrong          -> " :("
              Right          -> " :)"

updateStatus :: UI.Element -> IORef CompGraph -> UI ()
updateStatus e compGraphRef = do
  g <- UI.liftIO $ readIORef compGraphRef
  let getLabel   = commas . (map equLabel) . equations
      isJudged v = status v /= Unassessed
      slen       = show . length
      ns = filter (not . isRoot) (preorder g)
      js = filter isJudged ns
      fs = faultyVertices g
      txt = if length fs > 0 then " Fault detected in: " ++ getLabel (head fs)
                             else " Judged " ++ slen js ++ "/" ++ slen ns
  UI.element e # UI.set UI.text txt
  return ()

updateTree :: UI.Element -> IORef CompGraph -> (Maybe Vertex) -> (CompGraph -> CompGraph)
           -> UI ()
updateTree img treeRef mcv f
  = do tree <- UI.liftIO $ readIORef treeRef
       UI.liftIO $ writeIORef treeRef (f tree)
       redraw img treeRef mcv

redrawWith :: UI.Element -> IORef CompGraph -> IORef [Vertex] -> IORef Int -> UI ()
redrawWith img treeRef filteredVerticesRef currentVertexRef = do
  mv <- UI.liftIO $ lookupCurrentVertex currentVertexRef filteredVerticesRef
  redraw img treeRef mv

redraw :: UI.Element -> IORef CompGraph -> (Maybe Vertex) -> UI ()
redraw img treeRef mcv
  = do tree <- UI.liftIO $ readIORef treeRef
       UI.liftIO $ writeFile "debugTree.dot" (shw tree)
       UI.liftIO $ system $ "dot -Tpng -Gsize=9,5 -Gdpi=100 debugTree.dot "
                          ++ "> wwwroot/debugTree.png"
       url <- UI.loadFile "image/png" "wwwroot/debugTree.png"
       UI.element img # UI.set UI.src url
       return ()

  where shw g = showWith g (coloVertex $ faultyVertices g) showArc
        coloVertex fs v = ( summarizeVertex fs v 
                          , case mcv of (Just w) -> if equations v == equations w 
                                                        then "style=filled fillcolor=yellow"
                                                        else ""
                                        Nothing  ->          ""
                          )
        showArc _  = ""

        -- showVertex :: [Vertex] -> Vertex -> String
        -- showVertex _ Root = "root"
        -- showVertex fs v = showStatus fs v ++ ":\n" ++ showCompStmts v
        --                   ++ "\nwith stack " ++ (show . equStack . head . equations $ v)

        -- showVertexSimple fs v = showStatus fs v ++ ":" ++ showCompStmtsSimple v
        -- showCompStmtsSimple = commas . (map equLabel) . equations

        -- showStatus fs v
        --   | v `elem` fs = "Faulty"
        --   | otherwise   = (show . status) v

        -- showVertex = show
        -- showVertex = (foldl (++) "") . (map show) . equations

commas :: [String] -> String
commas [e] = e
commas es  = foldl (\acc e-> acc ++ e ++ ", ") "{" (init es) 
                     ++ show (last es) ++ "}"

faultyVertices :: CompGraph -> [Vertex]
faultyVertices = findFaulty_dag getStatus
  where getStatus Root = Right
        getStatus v    = status v
