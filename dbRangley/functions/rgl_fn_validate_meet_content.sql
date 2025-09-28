-- Ultra-comprehensive function to validate meet content for illegal activities
-- Fixed version with case-insensitive regex and better logging
CREATE OR REPLACE FUNCTION rangley.rgl_fn_validate_meet_content(
     p_name TEXT
    ,p_user_id INT8
    ,p_description TEXT DEFAULT ''
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSON;
    v_name_clean TEXT;
    v_description_clean TEXT;
    v_combined_text TEXT;
    v_combined_spaces TEXT;
BEGIN
    -- Normalize the inputs (trim whitespace, lowercase, remove special characters)
    v_name_clean := LOWER(TRIM(COALESCE(p_name, '')));
    v_description_clean := LOWER(TRIM(COALESCE(p_description, '')));
    v_combined_text := v_name_clean || ' ' || v_description_clean;
    v_combined_spaces := ' ' || REGEXP_REPLACE(v_combined_text, '[^a-z0-9\s]', ' ', 'g') || ' ';
    
    -- Log what we're checking for debugging
    RAISE LOG 'Content validation checking: "%"', v_combined_text;
    
    -- Basic validation for name
    IF v_name_clean IS NULL OR LENGTH(v_name_clean) = 0 THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'name_empty',
            'message', 'Meet name cannot be empty'
        );
    END IF;
    
    -- CATEGORY 1: TERRORISM AND VIOLENT EXTREMISM
    IF v_combined_text ~* '(bomb|explosive|ied|improvised\s+explosive|pressure\s+cooker|fertilizer\s+bomb|pipe\s+bomb|car\s+bomb|suicide\s+bomb)'
       OR v_combined_text ~* '(terrorist|terrorism|jihad|martyrdom|allahu\s+akbar|death\s+to\s+america|death\s+to\s+infidels)'
       OR v_combined_text ~* '(isis|al\s+qaeda|taliban|boko\s+haram|hezbollah|hamas|muslim\s+brotherhood)'
       OR v_combined_text ~* '(white\s+supremacist|neo\s+nazi|kkk|aryan\s+nation|proud\s+boys|oath\s+keepers|three\s+percenters)'
       OR v_combined_text ~* '(antifa\s+cell|black\s+bloc|direct\s+action|revolutionary\s+action|armed\s+resistance)'
       OR v_combined_text ~* '(mass\s+shooting|school\s+shooting|workplace\s+violence|active\s+shooter|rampage)'
       OR v_combined_text ~* '(chemical\s+weapon|biological\s+weapon|ricin|anthrax|sarin|mustard\s+gas)'
       OR v_combined_text ~* '(lone\s+wolf|sleeper\s+cell|safe\s+house|training\s+camp|weapons\s+cache|ammunition\s+stockpile)'
       OR v_combined_text ~* '(target\s+practice|tactical\s+training|urban\s+warfare|guerrilla\s+warfare|asymmetric\s+warfare)'
       OR v_combined_text ~* '(manifesto|final\s+message|last\s+testament|martyrdom\s+video|goodbye\s+world)'
    THEN
        INSERT INTO rangley.tb_content_violations (violation_category_id, user_id, attempted_name, attempted_description)
        VALUES (11, p_user_id, p_name, p_description);
        
        RAISE LOG 'CRITICAL: Terrorist content detected - combined_text: "%"', v_combined_text;
        RETURN json_build_object('valid', FALSE, 'reason', 'content_terrorism', 'message', 'Content contains language related to terrorism or violent extremism');
    END IF;
    
    -- CATEGORY 2: CHILD SEXUAL ABUSE AND EXPLOITATION
    IF v_combined_text ~* '(child\s+porn|cp|kiddie\s+porn|loli|shota|preteen|underage\s+sex|minor\s+sex)'
       OR v_combined_text ~* '(school\s+girl|little\s+girl|young\s+boy|teen\s+sex|jailbait|barely\s+legal)'
       OR v_combined_text ~* '(grooming|child\s+abuse|sexual\s+abuse|molestation|pedophile|pedo)'
       OR v_combined_text ~* '(candy\s+van|playground\s+meetup|after\s+school|babysitting\s+job|tutoring\s+session)'
       OR v_combined_text ~* '(age\s+of\s+consent|statutory\s+rape|runaway|missing\s+child|custody\s+dispute)'
       OR v_combined_text ~* '(webcam\s+show|private\s+photos|modeling\s+gig|photography\s+session).*(young|teen|minor|child)'
       OR v_combined_text ~* '(sugar\s+daddy|older\s+man|mature\s+gentleman|experienced\s+teacher).*(young|teen|school)'
       OR v_combined_text ~* '(no\s+parents|parents\s+away|home\s+alone|skip\s+school|ditch\s+class|after\s+school\s+special)'
       OR v_combined_text ~* '(playground|elementary|middle\s+school|high\s+school|daycare|summer\s+camp).*(meetup|private|alone)'
       OR v_combined_text ~* '(virgin|innocent|naive|inexperienced|first\s+time).*(young|teen|minor|child|school)'
    THEN
        INSERT INTO rangley.tb_content_violations (violation_category_id, user_id, attempted_name, attempted_description)
        VALUES (12, p_user_id, p_name, p_description);
        
        RAISE LOG 'CRITICAL: Child exploitation content detected - combined_text: "%"', v_combined_text;
        RETURN json_build_object('valid', FALSE, 'reason', 'content_child_exploitation', 'message', 'Content contains language that could facilitate child exploitation');
    END IF;
    
    -- CATEGORY 3: HUMAN TRAFFICKING AND FORCED LABOR
    IF v_combined_text ~* '(human\s+trafficking|sex\s+trafficking|forced\s+labor|modern\s+slavery|debt\s+bondage)'
       OR v_combined_text ~* '(no\s+papers|undocumented|illegal\s+immigrant|visa\s+expired|deportation)'
       OR v_combined_text ~* '(massage\s+parlor|escort\s+service|happy\s+ending|full\s+service|around\s+the\s+world)'
       OR v_combined_text ~* '(mail\s+order\s+bride|foreign\s+bride|desperate\s+women|third\s+world|poor\s+country)'
       OR v_combined_text ~* '(work\s+visa|sponsor\s+needed|cash\s+only|no\s+questions|under\s+the\s+table)'
       OR v_combined_text ~* '(runaway|homeless|nowhere\s+to\s+go|need\s+shelter|desperate\s+for\s+money)'
       OR v_combined_text ~* '(pimp|madam|stable|bottom\s+bitch|working\s+girl|street\s+walker)'
       OR v_combined_text ~* '(john|trick|client|customer).*(sex|prostitute|escort|massage)'
       OR v_combined_text ~* '(recruitment|job\s+opportunity|modeling\s+career).*(overseas|foreign|travel)'
       OR v_combined_text ~* '(passport\s+held|documents\s+confiscated|cant\s+leave|trapped|forced\s+to\s+work)'
    THEN
        INSERT INTO rangley.tb_content_violations (violation_category_id, user_id, attempted_name, attempted_description)
        VALUES (13, p_user_id, p_name, p_description);
        
        RAISE LOG 'CRITICAL: Human trafficking content detected - combined_text: "%"', v_combined_text;
        RETURN json_build_object('valid', FALSE, 'reason', 'content_human_trafficking', 'message', 'Content contains language related to human trafficking or forced labor');
    END IF;
    
    -- CATEGORY 4: DRUG MANUFACTURING AND DISTRIBUTION
    IF v_combined_text ~* '(meth\s+lab|crack\s+house|drug\s+lab|cooking\s+meth|making\s+drugs|drug\s+manufacturing)'
       OR v_combined_text ~* '(fentanyl|carfentanil|synthetic\s+opioids|designer\s+drugs|bath\s+salts|spice|k2)'
       OR v_combined_text ~* '(drug\s+dealer|drug\s+supplier|connect|plug|dope\s+man|trap\s+house)'
       OR v_combined_text ~* '(buy\s+drugs|sell\s+drugs|drug\s+deal|drug\s+trade|drug\s+exchange|drug\s+transaction)'
       OR v_combined_text ~* '(cocaine|heroin|meth|methamphetamine|crack|ecstasy|mdma|lsd|pcp|ketamine)'
       OR v_combined_text ~* '(prescription\s+drugs|oxy|oxycontin|adderall|xanax|percocet|vicodin|morphine)'
       OR v_combined_text ~* '(pill\s+mill|prescription\s+fraud|fake\s+prescription|doctor\s+shopping)'
       OR v_combined_text ~* '(drug\s+party|rave\s+supplies|party\s+favors|molly|rolls|tabs|dime\s+bag)'
       OR v_combined_text ~* '(grow\s+operation|hydroponic|cultivation|harvest|trimming|dispensary)'
       OR v_combined_text ~* '(precursor\s+chemicals|pseudoephedrine|anhydrous\s+ammonia|red\s+phosphorus)'
       OR v_combined_text ~* '(drug\s+money|laundering|clean\s+money|dirty\s+money|cash\s+business)'
    THEN
        INSERT INTO rangley.tb_content_violations (violation_category_id, user_id, attempted_name, attempted_description)
        VALUES (14, p_user_id, p_name, p_description);
        
        RAISE LOG 'CRITICAL: Drug distribution content detected - combined_text: "%"', v_combined_text;
        RETURN json_build_object('valid', FALSE, 'reason', 'content_drug_distribution', 'message', 'Content contains language related to illegal drug activities');
    END IF;
    
    -- CATEGORY 5: WEAPONS AND ILLEGAL FIREARMS
    IF v_combined_text ~* '(illegal\s+weapons|black\s+market\s+guns|unregistered\s+firearms|ghost\s+gun|3d\s+printed\s+gun)'
       OR v_combined_text ~* '(automatic\s+weapons|machine\s+gun|assault\s+rifle|high\s+capacity|bump\s+stock)'
       OR v_combined_text ~* '(gun\s+running|arms\s+dealer|weapons\s+trafficking|straw\s+purchase|private\s+sale)'
       OR v_combined_text ~* '(no\s+background\s+check|no\s+paperwork|cash\s+only|untraceable|off\s+the\s+books)'
       OR v_combined_text ~* '(silencer|suppressor|armor\s+piercing|hollow\s+point|explosive\s+rounds)'
       OR v_combined_text ~* '(ak47|ar15|uzi|mac10|tec9|glock\s+switch|auto\s+sear)'
       OR v_combined_text ~* '(gun\s+show\s+loophole|private\s+seller|parking\s+lot\s+sale|trunk\s+sale)'
       OR v_combined_text ~* '(converted\s+weapon|modified\s+trigger|full\s+auto|select\s+fire)'
       OR v_combined_text ~* '(stockpile|arsenal|cache|ammunition\s+dump|weapons\s+stash)'
       OR v_combined_text ~* '(survivalist|prepper|militia|compound|bunker).*(weapons|guns|ammo)'
    THEN
        INSERT INTO rangley.tb_content_violations (violation_category_id, user_id, attempted_name, attempted_description)
        VALUES (15, p_user_id, p_name, p_description);
        
        RAISE LOG 'CRITICAL: Illegal weapons content detected - combined_text: "%"', v_combined_text;
        RETURN json_build_object('valid', FALSE, 'reason', 'content_illegal_weapons', 'message', 'Content contains language related to illegal weapons or firearms');
    END IF;
    
    -- CATEGORY 6: PROSTITUTION AND SEXUAL SERVICES
    IF v_combined_text ~* '(prostitute|hooker|call\s+girl|escort|sex\s+worker|working\s+girl)'
       OR v_combined_text ~* '(full\s+service|gfe|girlfriend\s+experience|pse|porn\s+star\s+experience)'
       OR v_combined_text ~* '(incall|outcall|hotel\s+visit|car\s+date|quick\s+visit)'
       OR v_combined_text ~* '(massage\s+parlor|body\s+rub|sensual\s+massage|happy\s+ending|release)'
       OR v_combined_text ~* '(roses|donations|gifts|generous|financial\s+assistance).*(companionship|time|services)'
       OR v_combined_text ~* '(sugar\s+baby|arrangement|allowance|ppm|pay\s+per\s+meet)'
       OR v_combined_text ~* '(adult\s+entertainment|exotic\s+dancer|private\s+show|lap\s+dance|strip\s+club)'
       OR v_combined_text ~* '(brothel|bordello|cat\s+house|red\s+light|pleasure\s+house)'
       OR v_combined_text ~* '(john|trick|client|customer|regular).*(rate|price|fee|cost)'
       OR v_combined_text ~* '(pimp|madam|manager|agency|booker)'
       OR v_combined_text ~* '(backpage|craigslist|listcrawler|skipthegames|bedpage)'
    THEN
        INSERT INTO rangley.tb_content_violations (violation_category_id, user_id, attempted_name, attempted_description)
        VALUES (16, p_user_id, p_name, p_description);
        
        RAISE LOG 'CRITICAL: Prostitution content detected - combined_text: "%"', v_combined_text;
        RETURN json_build_object('valid', FALSE, 'reason', 'content_prostitution', 'message', 'Content contains language related to prostitution or sexual services');
    END IF;
    
    -- CATEGORY 7: ORGANIZED CRIME AND RACKETEERING
    IF v_combined_text ~* '(mafia|mob|cosa\s+nostra|cartel|gang|organized\s+crime)'
       OR v_combined_text ~* '(money\s+laundering|racketeering|extortion|protection\s+money|shakedown)'
       OR v_combined_text ~* '(loan\s+shark|juice\s+loan|vig|collection|break\s+legs)'
       OR v_combined_text ~* '(gambling\s+ring|bookmaking|numbers\s+game|underground\s+casino|back\s+room)'
       OR v_combined_text ~* '(chop\s+shop|stolen\s+cars|car\s+theft|auto\s+theft|parts\s+operation)'
       OR v_combined_text ~* '(fence|stolen\s+goods|hot\s+merchandise|black\s+market|contraband)'
       OR v_combined_text ~* '(hit|contract|elimination|whack|take\s+out|make\s+disappear)'
       OR v_combined_text ~* '(family\s+business|made\s+man|capo|underboss|don|boss)'
       OR v_combined_text ~* '(turf\s+war|territory|street\s+tax|tribute|omerta|code\s+of\s+silence)'
       OR v_combined_text ~* '(smuggling\s+operation|border\s+crossing|mule|courier|transport)'
    THEN
        INSERT INTO rangley.tb_content_violations (violation_category_id, user_id, attempted_name, attempted_description)
        VALUES (17, p_user_id, p_name, p_description);
        
        RAISE LOG 'CRITICAL: Organized crime content detected - combined_text: "%"', v_combined_text;
        RETURN json_build_object('valid', FALSE, 'reason', 'content_organized_crime', 'message', 'Content contains language related to organized crime activities');
    END IF;
    
    -- CATEGORY 8: FINANCIAL CRIMES AND FRAUD
    IF v_combined_text ~* '(ponzi\s+scheme|pyramid\s+scheme|investment\s+fraud|securities\s+fraud)'
       OR v_combined_text ~* '(identity\s+theft|credit\s+card\s+fraud|bank\s+fraud|wire\s+fraud)'
       OR v_combined_text ~* '(money\s+laundering|structuring|smurfing|cash\s+intensive|bulk\s+cash)'
       OR v_combined_text ~* '(fake\s+id|forged\s+documents|counterfeit\s+money|phishing\s+scam)'
       OR v_combined_text ~* '(tax\s+evasion|offshore\s+accounts|shell\s+company|nominee\s+account)'
       OR v_combined_text ~* '(insurance\s+fraud|staged\s+accident|slip\s+and\s+fall|workers\s+comp)'
       OR v_combined_text ~* '(romance\s+scam|catfish|nigerian\s+prince|inheritance\s+scam|lottery\s+scam)'
       OR v_combined_text ~* '(check\s+kiting|account\s+takeover|sim\s+swapping|social\s+engineering)'
       OR v_combined_text ~* '(cryptocurrency\s+scam|bitcoin\s+mixer|tumbler|privacy\s+coin)'
       OR v_combined_text ~* '(embezzlement|skimming|kickback|bribery|corruption)'
    THEN
        INSERT INTO rangley.tb_content_violations (violation_category_id, user_id, attempted_name, attempted_description)
        VALUES (18, p_user_id, p_name, p_description);
        
        RAISE LOG 'CRITICAL: Financial crime content detected - combined_text: "%"', v_combined_text;
        RETURN json_build_object('valid', FALSE, 'reason', 'content_financial_crime', 'message', 'Content contains language related to financial crimes or fraud');
    END IF;
    
    -- CATEGORY 9: CYBERCRIME AND HACKING
    IF v_combined_text ~* '(hacking|cracking|phishing|malware|ransomware|botnet)'
       OR v_combined_text ~* '(dark\s+web|tor\s+browser|onion\s+sites|deep\s+web|hidden\s+services)'
       OR v_combined_text ~* '(ddos|denial\s+of\s+service|sql\s+injection|zero\s+day|exploit)'
       OR v_combined_text ~* '(stolen\s+data|data\s+breach|database\s+dump|credit\s+card\s+numbers)'
       OR v_combined_text ~* '(keylogger|trojan|virus|spyware|adware|rootkit)'
       OR v_combined_text ~* '(carding|dumps|fullz|cvv|skimming|atm\s+skimmer)'
       OR v_combined_text ~* '(social\s+engineering|sim\s+swapping|account\s+takeover|credential\s+stuffing)'
       OR v_combined_text ~* '(cryptocurrency\s+mining|illegal\s+mining|cryptojacking)'
       OR v_combined_text ~* '(piracy|warez|cracked\s+software|keygen|serial\s+numbers)'
       OR v_combined_text ~* '(anonymous|vpn|proxy|secure\s+communication).*(illegal|criminal|hack)'
    THEN
        INSERT INTO rangley.tb_content_violations (violation_category_id, user_id, attempted_name, attempted_description)
        VALUES (19, p_user_id, p_name, p_description);
        
        RAISE LOG 'CRITICAL: Cybercrime content detected - combined_text: "%"', v_combined_text;
        RETURN json_build_object('valid', FALSE, 'reason', 'content_cybercrime', 'message', 'Content contains language related to cybercrime or hacking activities');
    END IF;
    
    -- CATEGORY 10: HATE CRIMES AND DISCRIMINATORY VIOLENCE
    IF v_combined_text ~* '(burn\s+cross|lynch|hang|string\s+up|tar\s+and\s+feather)'
       OR v_combined_text ~* '(synagogue|mosque|church|temple).*(bomb|attack|burn|destroy)'
       OR v_combined_text ~* '(race\s+war|ethnic\s+cleansing|genocide|final\s+solution)'
       OR v_combined_text ~* '(gay\s+bash|fag\s+drag|beat\s+up\s+queers|kill\s+the\s+gays)'
       OR v_combined_text ~* '(immigrant\s+hunt|deport\s+them\s+all|build\s+the\s+wall|send\s+them\s+back)'
       OR v_combined_text ~* '(white\s+power|white\s+supremacy|master\s+race|racial\s+purity)'
       OR v_combined_text ~* '(hitler\s+was\s+right|heil\s+hitler|sieg\s+heil|14\s+words)'
       OR v_combined_text ~* '(kkk|ku\s+klux|white\s+hood|cross\s+burning)'
       OR v_combined_text ~* '(neo\s+nazi|skinhead|blood\s+and\s+honor|white\s+nationalist)'
       OR v_combined_text ~* '(jews\s+will\s+not\s+replace|great\s+replacement|white\s+genocide)'
    THEN
        INSERT INTO rangley.tb_content_violations (violation_category_id, user_id, attempted_name, attempted_description)
        VALUES (20, p_user_id, p_name, p_description);
        
        RAISE LOG 'CRITICAL: Hate crime content detected - combined_text: "%"', v_combined_text;
        RETURN json_build_object('valid', FALSE, 'reason', 'content_hate_crime', 'message', 'Content contains language that could incite hate crimes or discriminatory violence');
    END IF;

	-- CATEGORY 10.5: HATE SPEECH AND RACIAL SLURS
    IF v_combined_text ~* '\y(n[i1]gg[ae]r?s?|f[a4]gg[o0]ts?|sp[i1]ck?s?|ch[i1]nks?|k[i1]kes?|w[e3]tb[a4]ck|b[e3][a4]n[e3]r|c[o0]{2}n|h[o0]nky|cr[a4]ck[e3]r|wh[i1]t[e3]y|r[a4]g\s?h[e3][a4]d|s[a4]nd\s?n[i1]gg[e3]r|t[o0]w[e3]l\s?h[e3][a4]d)\y'
    THEN
        INSERT INTO rangley.tb_content_violations (violation_category_id, user_id, attempted_name, attempted_description)
        VALUES (26, p_user_id, p_name, p_description);
        
        RAISE LOG 'CRITICAL: Hate speech content detected - combined_text: "%"', v_combined_text;
        RETURN json_build_object('valid', FALSE, 'reason', 'content_hate_speech', 'message', 'Content contains hate speech or slurs that violate community guidelines');
    END IF;

    -- CATEGORY 11: KIDNAPPING AND ABDUCTION
    IF v_combined_text ~ '(kidnap|abduct|snatch|grab|take|capture).*(child|kid|person|someone)'
       OR v_combined_text ~ '(ransom|hostage|captive|prisoner|held\s+against|locked\s+up)'
       OR v_combined_text ~ '(van\s+with\s+no\s+windows|soundproof|basement|hidden\s+room|remote\s+location)'
       OR v_combined_text ~ '(zip\s+ties|duct\s+tape|rope|chains|restraints|gag)'
       OR v_combined_text ~ '(missing\s+person|amber\s+alert|runaway|disappeared|vanished)'
       OR v_combined_text ~ '(lure|trick|deceive|false\s+pretenses|fake\s+emergency)'
       OR v_combined_text ~ '(isolated|remote|abandoned|deserted).*(location|building|warehouse|cabin)'
       OR v_combined_text ~ '(no\s+one\s+will\s+find|never\s+be\s+found|make\s+disappear|without\s+a\s+trace)'
    THEN
        INSERT INTO rangley.tb_content_violations (violation_category_id, user_id, attempted_name, attempted_description)
        VALUES (21, p_user_id, p_name, p_description);
        
        RAISE LOG 'CRITICAL: Kidnapping content detected - name=%, description=%', p_name, p_description;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'content_kidnapping',
            'message', 'Content contains language related to kidnapping or abduction'
        );
    END IF;
    
    -- CATEGORY 12: ANIMAL CRUELTY AND ILLEGAL ANIMAL ACTIVITIES
    IF v_combined_text ~ '(dog\s+fighting|cock\s+fighting|animal\s+fighting|blood\s+sport)'
       OR v_combined_text ~ '(animal\s+cruelty|torture\s+animals|kill\s+animals|abuse\s+animals)'
       OR v_combined_text ~ '(puppy\s+mill|kitten\s+mill|breeding\s+operation|backyard\s+breeder)'
       OR v_combined_text ~ '(exotic\s+animals|illegal\s+pets|smuggling\s+animals|endangered\s+species)'
       OR v_combined_text ~ '(poaching|illegal\s+hunting|trophy\s+hunting|ivory|rhino\s+horn)'
       OR v_combined_text ~ '(bestiality|zoophilia|animal\s+sex|sexual\s+abuse\s+of\s+animals)'
       OR v_combined_text ~ '(crush\s+videos|snuff\s+films|animal\s+torture\s+videos)'
    THEN
        INSERT INTO rangley.tb_content_violations (violation_category_id, user_id, attempted_name, attempted_description)
        VALUES (22, p_user_id, p_name, p_description);
        
        RAISE LOG 'CRITICAL: Animal cruelty content detected - name=%, description=%', p_name, p_description;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'content_animal_cruelty',
            'message', 'Content contains language related to animal cruelty or illegal animal activities'
        );
    END IF;
    
    -- CATEGORY 13: ADDITIONAL SEXUAL CRIMES
    IF v_combined_text ~ '(rape|sexual\s+assault|non\s+consensual|against\s+their\s+will)'
       OR v_combined_text ~ '(roofie|date\s+rape\s+drug|ghb|rohypnol|spike\s+drink)'
       OR v_combined_text ~ '(revenge\s+porn|non\s+consensual\s+porn|intimate\s+images|leaked\s+photos)'
       OR v_combined_text ~ '(voyeur|upskirt|hidden\s+camera|spy\s+cam|bathroom\s+cam)'
       OR v_combined_text ~ '(indecent\s+exposure|flashing|public\s+masturbation|lewd\s+conduct)'
       OR v_combined_text ~ '(sexual\s+harassment|unwanted\s+touching|groping|inappropriate\s+contact)'
       OR v_combined_text ~ '(stalking|following|watching|surveillance|obsessed)'
    THEN
        INSERT INTO rangley.tb_content_violations (violation_category_id, user_id, attempted_name, attempted_description)
        VALUES (23, p_user_id, p_name, p_description);
        
        RAISE LOG 'CRITICAL: Sexual crime content detected - name=%, description=%', p_name, p_description;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'content_sexual_crime',
            'message', 'Content contains language related to sexual crimes or harassment'
        );
    END IF;
    
    -- CATEGORY 14: ENVIRONMENTAL CRIMES
    IF v_combined_text ~ '(illegal\s+dumping|toxic\s+waste|hazardous\s+materials|chemical\s+spill)'
       OR v_combined_text ~ '(poaching|illegal\s+fishing|overfishing|protected\s+species)'
       OR v_combined_text ~ '(logging|deforestation|protected\s+forest|national\s+park)'
       OR v_combined_text ~ '(pollution|contamination|environmental\s+damage|ecological\s+destruction)'
    THEN
        INSERT INTO rangley.tb_content_violations (violation_category_id, user_id, attempted_name, attempted_description)
        VALUES (24, p_user_id, p_name, p_description);
        
        RAISE LOG 'Environmental crime content detected - name=%, description=%', p_name, p_description;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'content_environmental_crime',
            'message', 'Content contains language related to environmental crimes'
        );
    END IF;
    
    -- CATEGORY 15: BORDER AND IMMIGRATION CRIMES
    IF v_combined_text ~ '(human\s+smuggling|coyote|border\s+crossing|illegal\s+entry)'
       OR v_combined_text ~ '(fake\s+passport|forged\s+visa|document\s+fraud|identity\s+fraud)'
       OR v_combined_text ~ '(safe\s+house|stash\s+house|drop\s+off|pickup|transport)'
       OR v_combined_text ~ '(undocumented|no\s+papers|visa\s+overstay|deportation)'
    THEN
        INSERT INTO rangley.tb_content_violations (violation_category_id, user_id, attempted_name, attempted_description)
        VALUES (25, p_user_id, p_name, p_description);
        
        RAISE LOG 'Immigration crime content detected - name=%, description=%', p_name, p_description;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'content_immigration_crime',
            'message', 'Content contains language related to immigration violations'
        );
    END IF;
    
    -- Content passed all validation checks
    RETURN json_build_object(
        'valid', TRUE,
        'reason', 'content_valid',
        'message', 'Meet content is appropriate'
    );
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error but don't expose internal details
        RAISE LOG 'Error in rgl_fn_validate_meet_content: %', SQLERRM;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'validation_failed',
            'message', 'Unable to validate meet content'
        );
END;
$$;