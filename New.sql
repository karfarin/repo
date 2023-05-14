FUNCTION validation (p_acct         IN     VARCHAR2,
                            p_id           IN OUT VARCHAR2,
                            p_error_code      OUT VARCHAR2,
                            p_error_desc      OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        v_tran_date              DATE;
        v_acct_internal_key      NUMBER;
        v_dbtr_name              fm_client.client_name%TYPE;
        v_client_no              rb_acct.client_no%TYPE;
        v_id_type                fm_client.global_id_type%TYPE;
        v_client_type            fm_client.client_type%TYPE;
        v_country                fm_client.country_citizen%TYPE;
        v_id_cor                 VARCHAR2 (15);
        v_id_nid                 VARCHAR2 (15);
        v_id                     VARCHAR2 (12);
        v_check_national_id      VARCHAR2 (250) := NULL;
        v_check_corporation_id   VARCHAR2 (250) := NULL;
        v_step                   VARCHAR2 (4);
    BEGIN
        v_step := '1';

        p_error_code := '000000';
        v_tran_date := get_run_date;
        v_id := p_id;

        BEGIN
            SELECT internal_key,
                   a.client_no,
                   b.client_type,
                   b.global_id_type,
                   b.client_name,
                   b.country_citizen
              INTO v_acct_internal_key,
                   v_client_no,
                   v_client_type,
                   v_id_type,
                   v_dbtr_name,
                   v_country
              FROM rb_acct a, fm_client b
             WHERE a.client_no = b.client_no AND acct_no = p_acct;
        EXCEPTION
            WHEN OTHERS
            THEN
                BEGIN
                    SELECT internal_key,
                           a.client_no,
                           b.client_type,
                           b.global_id_type,
                           b.client_name,
                           b.country_citizen
                      INTO v_acct_internal_key,
                           v_client_no,
                           v_client_type,
                           v_id_type,
                           v_dbtr_name,
                           v_country
                      FROM rb_acct a, fm_client b
                     WHERE     a.client_no = b.client_no
                           AND b.client_no = p_acct
                           AND ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_error_code := '300395';    -- invalid client number;
                        RETURN FALSE;
                END;
        END;

        v_step := '2';

        IF v_id IS NULL OR v_id = ''
        THEN
            BEGIN
                IF v_client_type = '1'
                THEN
                    SELECT NVL (national_id, '0')
                      INTO v_id_nid
                      FROM fm_client_indvl
                     WHERE client_no = v_client_no;
                ELSE
                    SELECT NVL (corporation_id, '0')
                      INTO v_id_cor
                      FROM fm_client_corporate
                     WHERE client_no = v_client_no;
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_step := '3';

                    BEGIN
                        SELECT NVL (global_id, '0')
                          INTO v_id
                          FROM fm_client
                         WHERE client_no = v_client_no;

                        IF v_client_type = '1'
                        THEN
                            v_id_nid := v_id;
                        ELSE
                            v_id_cor := v_id;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            p_error_code := '104045';
                            RETURN FALSE;
                    END;
            END;

            v_step := '4';

            IF v_client_type = '1'
            THEN
                IF    v_id_type = 'FIN'
                   OR (v_id_type = 'PPT' AND v_country <> 'IR')
                THEN
                    v_step := '5';

                    SELECT NVL (global_id, '0')
                      INTO v_id
                      FROM fm_client
                     WHERE client_no = v_client_no;

                    v_id := SUBSTR (v_id, 1, 15);
                ELSE
                    v_step := '6';
                    v_check_national_id := validate_national_id (v_id_nid);

                    IF    v_check_national_id IS NULL
                       OR v_check_national_id <> '829204'
                    THEN
                        v_id := v_id_nid;
                    ELSE
                        p_error_code := '104045';
                        RETURN FALSE;
                    END IF;
                END IF;
            ELSE
                v_step := '7';
                v_check_corporation_id := validate_cor_id (v_id_cor);

                IF    v_check_corporation_id IS NULL
                   OR v_check_corporation_id <> '829205'
                THEN
                    v_id := v_id_cor;
                ELSE
                    p_error_code := '104045';
                    RETURN FALSE;
                END IF;
            END IF;
        ELSE
            v_step := '8';

            --v_id := p_id;

            IF v_client_type = '1'
            THEN
                IF    v_id_type = 'FIN'
                   OR (v_id_type = 'PPT' AND v_country <> 'IR')
                THEN
                    NULL;
                ELSE
                    v_step := '9';
                    v_check_national_id := validate_national_id (v_id);

                    IF v_check_national_id = '829204'
                    THEN
                        p_error_code := '104045';
                        p_error_desc :=
                            error_desc (NVL (p_error_code, '000000'));
                        RETURN FALSE;
                    END IF;
                END IF;
            ELSE
                v_step := '10';
                v_check_corporation_id := validate_cor_id (v_id);

                IF NVL (v_check_corporation_id, '~') = '829205'
                THEN
                    p_error_code := '104045';
                    p_error_desc := error_desc (NVL (p_error_code, '000000'));
                    RETURN FALSE;
                END IF;
            END IF;
        END IF;

        BEGIN
            IF v_client_type = '1'
            THEN
                SELECT NVL (national_id, '0')
                  INTO v_id_nid
                  FROM fm_client_indvl
                 WHERE client_no = v_client_no AND national_id = v_id;
            ELSE
                SELECT NVL (corporation_id, '0')
                  INTO v_id_cor
                  FROM fm_client_corporate
                 WHERE client_no = v_client_no AND corporation_id = v_id;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                v_step := '3';

                /*BEGIN
                    SELECT NVL (global_id, '0')
                      INTO v_id
                      FROM fm_client
                     WHERE client_no = v_client_no;

                    IF v_client_type = '1'
                    THEN
                        v_id_nid := v_id;
                    ELSE
                        v_id_cor := v_id;
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN*/
                p_error_code := '111221';
                RETURN FALSE;
        --END;
        END;



        P_id := v_id;
        p_error_desc := error_desc (NVL (p_error_code, '000000'));

        IF NVL (p_error_code, 0) = 0
        THEN
            p_error_code := '000000';
        END IF;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            BEGIN
                /*IF p_error_code IN (0, '000000')
                THEN
                    p_error_code := '000000';
                    p_error_desc := error_desc (p_error_code);
                ELS*/
                IF     p_error_code NOT IN (0, '000000')
                   AND p_error_code IS NOT NULL
                THEN
                    p_error_desc := error_desc (p_error_code);
                ELSE
                    p_error_code := SQLCODE;
                    p_error_desc := SQLERRM;
                END IF;
            END;

            ROLLBACK;

            insert_log (
                p_acct,
                p_id,                                          --v_seq_no_coi,
                'CL_OPENBANKING',
                'VALIDATION',
                SQLCODE,
                'CL',
                   'step : ['
                || v_step
                || ']'
                || ' SQLCODE : ['
                || p_error_code
                || ']'
                || ' SQLERRM : ['
                || p_error_desc
                || ']');
    END validation;