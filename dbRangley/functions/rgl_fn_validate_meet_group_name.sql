-- Comprehensive function to validate meet group names for inappropriate content
-- Returns JSON with validation status and optional message
-- Meet group names don't need to be unique but must be appropriate

CREATE OR REPLACE FUNCTION rangley.rgl_fn_validate_meet_group_name(
    p_meet_group_name TEXT,
    p_user_id INT8
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_result JSON;
    v_name_clean TEXT;
    v_name_spaces TEXT;
BEGIN
    -- Normalize the input (trim whitespace, lowercase, remove special characters for pattern matching)
    v_name_clean := LOWER(TRIM(COALESCE(p_meet_group_name, '')));
    v_name_spaces := ' ' || REGEXP_REPLACE(v_name_clean, '[^a-z0-9\s]', ' ', 'g') || ' ';
    
    -- Log what we're checking for debugging
    RAISE LOG 'Meet group name validation checking: "%"', v_name_clean;
    
    -- Basic validation
    IF v_name_clean IS NULL OR LENGTH(v_name_clean) = 0 THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_empty',
            'message', 'Meet Group Name cannot be empty'
        );
    END IF;
    
    -- Check minimum length
    IF LENGTH(v_name_clean) < 1 THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_too_short',
            'message', 'Meet Group Name must be at least 1 character'
        );
    END IF;
    
    -- Check maximum length
    IF LENGTH(v_name_clean) > 50 THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_too_long',
            'message', 'Meet Group Name must be 50 characters or less'
        );
    END IF;
    
    -- Check for excessive whitespace (more than 2 consecutive spaces)
    IF p_meet_group_name ~ '\s{3,}' THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_excessive_whitespace',
            'message', 'Meet Group Name cannot contain excessive whitespace'
        );
    END IF;
    
    -- Check for control characters and other problematic Unicode
    IF p_meet_group_name ~ '[\x00-\x1F\x7F-\x9F]' THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_control_chars',
            'message', 'Meet Group Name contains invalid characters'
        );
    END IF;
    
    -- CATEGORY 1: TERRORISM AND VIOLENT EXTREMISM
    IF v_name_clean ~* '(bomb|explosive|ied|improvised\s+explosive|terrorist|terrorism|jihad|isis|al\s+qaeda|taliban)'
       OR v_name_clean ~* '(white\s+supremacist|neo\s+nazi|kkk|aryan\s+nation|mass\s+shooting|school\s+shooting)'
       OR v_name_clean ~* '(chemical\s+weapon|biological\s+weapon|ricin|anthrax|sarin)'
    THEN
        RAISE LOG 'CRITICAL: Terrorist content detected in meet group name: "%"', v_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_terrorism',
            'message', 'Meet Group Name contains language related to terrorism or violent extremism'
        );
    END IF;
    
    -- CATEGORY 2: CHILD SEXUAL ABUSE AND EXPLOITATION
    IF v_name_clean ~* '(child\s+porn|cp|kiddie\s+porn|loli|shota|preteen|underage\s+sex|minor\s+sex)'
       OR v_name_clean ~* '(grooming|child\s+abuse|sexual\s+abuse|molestation|pedophile|pedo)'
       OR v_name_clean ~* '(jailbait|barely\s+legal)'
    THEN
        RAISE LOG 'CRITICAL: Child exploitation content detected in meet group name: "%"', v_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_child_exploitation',
            'message', 'Meet Group Name contains inappropriate content'
        );
    END IF;
    
    -- CATEGORY 3: HUMAN TRAFFICKING AND FORCED LABOR
    IF v_name_clean ~* '(human\s+trafficking|sex\s+trafficking|forced\s+labor|modern\s+slavery)'
       OR v_name_clean ~* '(pimp|madam|escort\s+service|prostitution)'
    THEN
        RAISE LOG 'CRITICAL: Human trafficking content detected in meet group name: "%"', v_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_human_trafficking',
            'message', 'Meet Group Name contains inappropriate content'
        );
    END IF;
    
    -- CATEGORY 4: DRUG MANUFACTURING AND DISTRIBUTION
    IF v_name_clean ~* '(meth\s+lab|crack\s+house|drug\s+lab|cooking\s+meth|making\s+drugs)'
       OR v_name_clean ~* '(drug\s+dealer|drug\s+supplier|sell\s+drugs|buy\s+drugs)'
       OR v_name_clean ~* '(fentanyl|carfentanil|synthetic\s+opioids)'
    THEN
        RAISE LOG 'CRITICAL: Drug distribution content detected in meet group name: "%"', v_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_drug_distribution',
            'message', 'Meet Group Name contains inappropriate content'
        );
    END IF;
    
    -- CATEGORY 5: WEAPONS AND ILLEGAL FIREARMS
    IF v_name_clean ~* '(illegal\s+weapons|black\s+market\s+guns|unregistered\s+firearms|ghost\s+gun)'
       OR v_name_clean ~* '(gun\s+running|arms\s+dealer|weapons\s+trafficking)'
    THEN
        RAISE LOG 'CRITICAL: Illegal weapons content detected in meet group name: "%"', v_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_illegal_weapons',
            'message', 'Meet Group Name contains inappropriate content'
        );
    END IF;
    
    -- CATEGORY 6: PROSTITUTION AND SEXUAL SERVICES
    IF v_name_clean ~* '(prostitute|hooker|call\s+girl|escort|sex\s+worker)'
       OR v_name_clean ~* '(full\s+service|girlfriend\s+experience|massage\s+parlor|happy\s+ending)'
       OR v_name_clean ~* '(sugar\s+baby|arrangement|brothel)'
    THEN
        RAISE LOG 'CRITICAL: Prostitution content detected in meet group name: "%"', v_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_prostitution',
            'message', 'Meet Group Name contains inappropriate content'
        );
    END IF;
    
    -- CATEGORY 7: ORGANIZED CRIME AND RACKETEERING
    IF v_name_clean ~* '(mafia|mob|cosa\s+nostra|cartel|organized\s+crime)'
       OR v_name_clean ~* '(money\s+laundering|racketeering|extortion|loan\s+shark)'
       OR v_name_clean ~* '(chop\s+shop|stolen\s+cars|fence|stolen\s+goods)'
    THEN
        RAISE LOG 'CRITICAL: Organized crime content detected in meet group name: "%"', v_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_organized_crime',
            'message', 'Meet Group Name contains inappropriate content'
        );
    END IF;
    
    -- CATEGORY 8: FINANCIAL CRIMES AND FRAUD
    IF v_name_clean ~* '(ponzi\s+scheme|pyramid\s+scheme|investment\s+fraud)'
       OR v_name_clean ~* '(identity\s+theft|credit\s+card\s+fraud|bank\s+fraud)'
       OR v_name_clean ~* '(fake\s+id|forged\s+documents|counterfeit\s+money)'
    THEN
        RAISE LOG 'CRITICAL: Financial crime content detected in meet group name: "%"', v_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_financial_crime',
            'message', 'Meet Group Name contains inappropriate content'
        );
    END IF;
    
    -- CATEGORY 9: CYBERCRIME AND HACKING
    IF v_name_clean ~* '(hacking|cracking|phishing|malware|ransomware)'
       OR v_name_clean ~* '(stolen\s+data|data\s+breach|credit\s+card\s+numbers)'
       OR v_name_clean ~* '(carding|dumps|fullz|cvv|skimming)'
    THEN
        RAISE LOG 'CRITICAL: Cybercrime content detected in meet group name: "%"', v_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_cybercrime',
            'message', 'Meet Group Name contains inappropriate content'
        );
    END IF;
    
    -- CATEGORY 10: HATE CRIMES AND DISCRIMINATORY VIOLENCE
    IF v_name_clean ~* '(lynch|burn\s+cross|ethnic\s+cleansing|genocide)'
       OR v_name_clean ~* '(race\s+war|white\s+power|white\s+supremacy|master\s+race)'
       OR v_name_clean ~* '(hitler\s+was\s+right|heil\s+hitler|sieg\s+heil)'
       OR v_name_clean ~* '(gay\s+bash|kill\s+the\s+gays)'
    THEN
        RAISE LOG 'CRITICAL: Hate crime content detected in meet group name: "%"', v_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_hate_crime',
            'message', 'Meet Group Name contains inappropriate content'
        );
    END IF;
    
    -- CATEGORY 10.5: HATE SPEECH AND RACIAL SLURS
    IF v_name_clean ~* '\y(n[i1]gg[ae]r?s?|f[a4]gg[o0]ts?|sp[i1]ck?s?|ch[i1]nks?|k[i1]kes?|w[e3]tb[a4]ck|b[e3][a4]n[e3]r|c[o0]{2}n|h[o0]nky|cr[a4]ck[e3]r|wh[i1]t[e3]y|r[a4]g\s?h[e3][a4]d|s[a4]nd\s?n[i1]gg[e3]r|t[o0]w[e3]l\s?h[e3][a4]d)\y'
    THEN
        RAISE LOG 'CRITICAL: Hate speech detected in meet group name: "%"', v_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_hate_speech',
            'message', 'Meet Group Name contains hate speech or slurs that violate community guidelines'
        );
    END IF;
    
    -- CATEGORY 11: KIDNAPPING AND ABDUCTION
    IF v_name_clean ~* '(kidnap|abduct|ransom|hostage)'
    THEN
        RAISE LOG 'CRITICAL: Kidnapping content detected in meet group name: "%"', v_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_kidnapping',
            'message', 'Meet Group Name contains inappropriate content'
        );
    END IF;
    
    -- CATEGORY 12: ANIMAL CRUELTY
    IF v_name_clean ~* '(dog\s+fighting|cock\s+fighting|animal\s+fighting|animal\s+cruelty)'
       OR v_name_clean ~* '(bestiality|zoophilia)'
    THEN
        RAISE LOG 'CRITICAL: Animal cruelty content detected in meet group name: "%"', v_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_animal_cruelty',
            'message', 'Meet Group Name contains inappropriate content'
        );
    END IF;
    
    -- CATEGORY 13: SEXUAL CRIMES
    IF v_name_clean ~* '(rape|sexual\s+assault|roofie|date\s+rape)'
       OR v_name_clean ~* '(revenge\s+porn|non\s+consensual\s+porn)'
       OR v_name_clean ~* '(voyeur|upskirt|hidden\s+camera|spy\s+cam)'
    THEN
        RAISE LOG 'CRITICAL: Sexual crime content detected in meet group name: "%"', v_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_sexual_crime',
            'message', 'Meet Group Name contains inappropriate content'
        );
    END IF;
    
    -- Check against basic profanity
    IF v_name_clean ~* '\b(fuck|shit|bitch|cunt|cock|dick|pussy|whore|slut|bastard)\b'
    THEN
        RAISE LOG 'Rejected profanity in meet group name: "%"', v_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_profanity',
            'message', 'Meet Group Name contains inappropriate language'
        );
    END IF;
    
    -- Check for profanity obfuscations
    IF v_name_clean ~* 'f[u_0*][c_*][k_*]|sh[i1!][t7]|b[i1!]tch|[a@4]ss[h]?[o0]le|wh[o0]r[e3]|sl[u_][t7]'
    THEN
        RAISE LOG 'Rejected obfuscated profanity in meet group name: "%"', v_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_profanity',
            'message', 'Meet Group Name contains inappropriate language'
        );
    END IF;
    
    -- Check for impersonation attempts (official roles/titles)
    IF v_name_clean ~* '\b(admin|administrator|moderator|mod|staff|official|rangley|support|founder|ceo|manager|employee|representative|team)\b'
    THEN
        RAISE LOG 'Rejected impersonation attempt in meet group name: "%"', v_name_clean;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_impersonation',
            'message', 'Meet Group Name cannot impersonate official roles'
        );
    END IF;
    
    -- Check for contact information (prevent doxxing/spam)
    IF v_name_clean ~ '\b(\+?[1-9][0-9]{7,14}|[0-9]{10})\b'
    THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_contains_phone',
            'message', 'Meet Group Name cannot contain phone numbers'
        );
    END IF;
    
    IF v_name_clean ~ '\b[a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,}\b'
    THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_contains_email',
            'message', 'Meet Group Name cannot contain email addresses'
        );
    END IF;
    
    -- Check for URLs/links
    IF v_name_clean ~ '\b(https?://|www\.|\.com|\.org|\.net|\.gov|\.edu)\b'
    THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_contains_url',
            'message', 'Meet Group Name cannot contain URLs or web addresses'
        );
    END IF;
    
    -- Check for excessive repetition (aaaaaaa, 1111111, etc.)
    IF v_name_clean ~ '(.)\1{6,}'
    THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_excessive_repetition',
            'message', 'Meet Group Name cannot contain excessive character repetition'
        );
    END IF;
    
    -- Check for only numbers (might be confused with IDs)
    IF v_name_clean ~ '^[0-9\s]+$'
    THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_only_numbers',
            'message', 'Meet Group Name cannot contain only numbers'
        );
    END IF;
    
    -- Check for only special characters
    IF v_name_clean ~ '^[^a-z0-9\s]+$'
    THEN
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'meet_group_name_only_special_chars',
            'message', 'Meet Group Name must contain at least one letter or number'
        );
    END IF;
    
    -- Meet Group Name is valid
    RETURN json_build_object(
        'valid', TRUE,
        'reason', 'meet_group_name_valid',
        'message', 'Meet Group Name is acceptable'
    );
    
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error but don't expose internal details
        RAISE LOG 'Error in rgl_fn_validate_meet_group_name: %', SQLERRM;
        RETURN json_build_object(
            'valid', FALSE,
            'reason', 'validation_failed',
            'message', 'Unable to validate Meet Group Name'
        );
END;
$$;