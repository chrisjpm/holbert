{-# LANGUAGE OverloadedStrings #-}
module View.ProofTree where
import Miso
import qualified Miso.String as MS
import Data.List (intersperse)
import Data.Maybe (isNothing, isJust, fromMaybe)
import DisplayOptions
import qualified Item as I
import qualified Rule as R
import qualified Prop as P
import ProofTree
import View.Prop
import View.Utils
import View.Term
import View.Paragraph (renderText)


renderProofTree opts pt tbl selected textIn = renderPT False False [] [] [] pt
  where
    
    termDOs = tDOs opts
    ruleDOs = RDO {termDisplayOptions = termDOs, showInitialMetas = True, ruleStyle = Turnstile}
    renderRR (P.Rewrite r fl) = span_ [class_ "rule-rulename-rewrite"]  [renderRR r, sup_ [] [if not fl then "→" else "←"]]
    renderRR (P.Elim r i) = span_ [class_ "rule-rulename-elim"] [renderRR r, sup_ [] [renderRR i]]
    renderRR (P.Defn d) = definedrule d
    renderRR (P.Local i) = localrule i

    currentGS = case selected of 
      Just (R.ProofFocus t g) -> g 
      _ -> Nothing

    renderPT inTree showPreamble rns ctx pth (PT ptopts sks lcls prp msgs) =
      let binders = (if showMetaBinders opts && not showPreamble then concat (zipWith (metabinder' pth) [0 ..] sks) else [])
                 ++ boundrules
          boundrules = if assumptionsMode opts == Hidden && not showPreamble then map rulebinder [length rns .. length rns + length lcls - 1] else []       
          premises = case msgs of
            Just (rr, sgs) -> zipWith (renderPT (inTree || shouldBeTree) (isJust ptopts) rns' ctx') (map (: pth) [0 ..]) sgs
            Nothing        -> []
          spacer = maybe (goalButton pth) (const $ "") msgs

          ruleTitle = Just $ maybe "?" (addNix . renderRR . fst) msgs


          subtitleWidget = case selected of
              Just (R.ProofFocus (R.SubtitleFocus pth') _) | pth == pth' -> editor "expanding" (R.SetSubgoalHeading pth) txt  
              _ -> button "editable editable-heading" "" (SetFocus (R.ProofFocus (R.SubtitleFocus pth) currentGS)) (renderText tbl txt)
            where txt = case ptopts of Nothing -> "Show:"; Just opts -> subtitle opts


          wordboundrules [] [] = []
          wordboundrules [] [(lab,c)] = [div_ []  [ span_ [class_ "item-rule-proofheading"] ["Assuming "], renderRR lab, ": ",renderPropNameE (InProofTree (selected,textIn)) Nothing ctx' ruleDOs c ]]
          wordboundrules [] ls = [div_ [class_ "item-rule-proofheading"] ["Assuming:"], ul_ [] (map (\(lab,c)-> li_ [] [renderRR lab, ": ", renderPropNameE (InProofTree (selected,textIn)) Nothing ctx' ruleDOs c]) ls)]
          wordboundrules vars [] = [div_ []  [ span_ [class_ "item-rule-proofheading"] ("Given " : concat (zipWith (metabinder' pth) [0 ..] vars)) ]]
          wordboundrules vars [(lab,c)] = [div_ []  [ span_ [class_ "item-rule-proofheading"] ("Given " : concat (zipWith (metabinder' pth) [0 ..] vars)), span_ [class_ "item-rule-proofheading"] [" where "], renderRR lab, ": ",renderPropNameE (InProofTree (selected,textIn)) Nothing ctx' ruleDOs c ]]
          wordboundrules vars ls = [div_ []  [ span_ [class_ "item-rule-proofheading"] ("Given " : concat (zipWith (metabinder' pth) [0 ..] vars)), span_ [class_ "item-rule-proofheading"] [" where:"], ul_ [] (map (\(lab,c)-> li_ [] [renderRR lab, ": ", renderPropNameE (InProofTree (selected,textIn)) Nothing ctx' ruleDOs c]) ls)]]
          preamble = div_ [class_ "word-proof-prop"] 
            $ (div_ [class_ "proof-subtitle"] [multi (wordboundrules (if showMetaBinders opts then sks else []) $ zip (map P.Local [length rns ..]) lcls)] :)
            $ (div_ [] [subtitleWidget]:)
            $ [div_ [class_ "word-proof-goal"] [ renderPropNameE (InProofTree (selected, textIn)) Nothing ctx' ruleDOs $ P.Forall [] [] prp ] ]

          conclusion = pure $ renderPropNameLabelledE (Just $ case assumptionsMode opts of
              New | not showPreamble -> map P.Local [length rns ..]
              Cumulative | not showPreamble -> map P.Local [0..]
              _ -> []) Nothing (InProofTree (selected, textIn)) Nothing ctx' ruleDOs
                           $ P.Forall [] (case assumptionsMode opts of
              New  | not showPreamble -> lcls
              Cumulative | not showPreamble -> rns'
              _ -> []) prp
       in if shouldShowWords then 
            multi $ (if showPreamble then id else (span_ [class_ "item-rule-proofheading"] ["Proof. "] :) )
                  $ (preamble:)
                  $ (multi [" by ", fromMaybe "" ruleTitle, spacer, if null premises then ". " else ": "]  :)
                  $ (styleButton :)
                  $ pure $ wordsrule premises 
          else 
            multi $ (if inTree || not showPreamble then id else (preamble:) )                
                  $ (if inTree || showPreamble then id else (span_ [class_ "item-rule-proofheading"] ["Proof. " ] :) )
                  $ (if inTree || not showPreamble then id else ("by: ":))
                  $ (if inTree then id else (styleButton :))
                  $ pure $ inferrule binders premises spacer ruleTitle conclusion                

      where
        wordsrule [p] =  div_ [class_ "word-proof"] [p]
        wordsrule premises =
          div_ [class_ "word-proof"] [ ul_ [] $ map (li_ [] . pure) premises ]
        styleButton = if shouldShowWords then 
                        iconButton "grey" "Switch to tree style" "tree" (Act $ R.ToggleStyle pth)
                      else 
                        iconButton "grey" "Switch to prose style" "flow-children" (Act $ R.ToggleStyle pth)
        shouldShowWords = not inTree && not shouldBeTree
        shouldBeTree = case ptopts of Nothing -> True; Just opts -> not (proseStyle opts)
        addNix t = multi [t, iconButton "red" "Delete proof subtree" "trash" (Act $ R.Nix pth)]

        rulebinder v = multi [localrule v, miniTurnstile]

        rns' = map (P.raise (length sks)) rns ++ lcls
        ctx' = reverse sks ++ ctx


    metabinder' pth i n = case selected of
      Just (R.ProofFocus (R.ProofBinderFocus pth' i') _) | pth == pth', i == i' -> [metabinderEditor pth i textIn]
      _ -> [button "editable editable-math" "" (SetFocus $ R.ProofFocus (R.ProofBinderFocus pth i) currentGS) [metabinder n]]

    metabinderEditor pth i n = editor "expanding" (R.RenameProofBinder pth i) n

    goalButton pth  = case selected of
      Just (R.ProofFocus _ (Just (R.GS _ _ _ pth' _)))  | pth == pth' -> focusedButton "button-icon button-icon-active button-icon-goal" "" (Act $ R.SelectGoal pth) [typicon "location"]
      _ -> button "button-icon button-icon-blue button-icon-goal" "Unsolved goal" (Act $ R.SelectGoal pth) [typicon "location-outline"]
