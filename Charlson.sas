/*********************************************

* Charlson comorbidity macro.sas
*
* Computes the Deyo version of the Charleson
*
*
*  Programmer
*     Hassan Fouayzi
*
*
* Input data required:
*
*     VDW Utilization files
*     Input SAS dataset INPUTDS
*        contains the variables MRN, STUDYID, and INDEXDT
*        INPATONLY flag - defauts to Inpatient only (I).  Valid values are
*                           I-inpatient or B-Both inpatient and outpatient
*                           or A-All encounter types
*        MALIG flag - Defaults to no(N).  If MALIG is yes (Y) then the weights
*                         of Metastasis and Malignancy are set to zero.
*                     This may be useful in a study of cancer.
*
*        NoEncounterGetsMissing - Defaults to (N).  Controls whether people for
*                                 whom no dx/px data is found get a charlson score
*                                 of 0 (default) or a missing value.  For cohorts whose
*                                 year-pre-index-date data capture is assured (usually via
*                                 enrollment data), having no encounters should legitimately
*                                 indicate a lack of any comorbidities & therefore a legit
*                                 score of 0.  Cohorts *not* previously vetted in this way may
*                                 not support that inference, and users should specify a Y
*                                 for this parameter to prevent unwarranted interpretation
*                                 of the Charlson score.
*
* Outputs:
*     Dataset &outputsd with on record per studyid
*     Variables
*       MI            = "Myocardial Infarction: "
*       CHD           = "Congestive heart disease: "
*       PVD           = "Peripheral vascular disorder: "
*       CVD           = "Cerebrovascular disease: "
*       DEM           = "Dementia: "
*       CPD           = "Chronic pulmonary disease: "
*       RHD           = "Rheumatologic disease: "
*       PUD           = "Peptic ulcer disease: "
*       MLIVD         = "Mild liver disease: "
*       DIAB          = "Diabetes: "
*       DIABC         = "Diabetes with chronic complications: "
*       PLEGIA        = "Hemiplegia or paraplegia: "
*       REN           = "Renal Disease: "
*       MALIGN        = "Malignancy, including leukemia and lymphoma: "
*       SLIVD         = "Moderate or severe liver disease: "
*       MST           = "Metastatic solid tumor: "
*       AIDS          = "AIDS: "
*       &IndexVarName = "Charlson score: "
*
*
* Dependencies:
*
*     To using this macro, better to add %include to include this macro before call it.
*     StdVars.sas--the site-customized list of standard macro variables.
*     The DX and PROC files to which stdvars.sas refer
*
*
* Example of use:
*     %charls10(testing,oot, Charles, inpatonly=B)
*
* Notes:
*   You will often need to remove certain disease format categories for your
*   project. For instance, the Ovarian Ca EOL study removed Metastatic Solid
*   Tumor since all were in end stages. It would be inappopriate not to exclude
*   this category in this instance. Please use this macro wisely.
*
*   There are several places that need to be modified.
*     1.  Comment the diagnosis category in the format.
*     2.  Remove that diagnosis category in 2 arrays.
*     3.  Select the time period for the source data and a reference point.
*     4.  Data selection.  All diagnoses and procedures?  Inpt only?  The user
*         may want to remove certain types of data to make the sources from all
*         sites consistent.
*
* Version History
*
*     Written by Hassan Fouayzi starting with source from Rick Krajenta
*     Modified into a SAS Macro format           Gene Hart         2005/04/20
*     Malig flag implemented                     Gene Hart         2005/05/04
*     Add flag to mark thos with no visits       Gene Hart         2005/05/09
*     Add additional codes to disease            Tyler Ross        2006/03/31
*     Changed EncType for IP visits to new ut
*       specs and allowed all visit types option Tyler Ross       2006/09/15
*     Removed "456" from Moderate/Severe Liver   Hassan Fouayzi    2006/12/21
*     Add ICD-10 Format (in below C001 mark)   Wei Tao           2015/11/18
*
*     Should the coalesce function be on studyid or mrn?  1 MRN with 2 STUDYIDs
*       could happen
*
*     move then proc codes to a format
*
* Source publication
*     From: Fouayzi, Hassan [mailto:hfouayzi@meyersprimary.org]
*     Sent: Wednesday, May 04, 2005 9:07 AM
*     Subject: RE: VDW Charlson macro
...
*     “Deyo RA, Cherkin DC, Ciol MA. Adapting a clinical comorbidity Index for
*     use with ICD-9-CM administrative databases.
*       J Clin Epidemiol 1992; 45: 613-619”.
*     We added CPT codes and a couple of procedures for Peripheral
*       vascular disorder.
*
*********************************************/
%macro charlson(inputds
               , IndexDateVarName
               , outputds
               , IndexVarName
               , inpatonly=I
               , malig=N
               , NoEncounterGetsMissing = N
               , enctype_list =
               , days_lookback = 365
               );

   /**********************************************/
   /*Define and format diagnosis codes*/
   /**********************************************/

   ** TODO:  Come up with an ICD-10 version of this format!!! ;
   ** C001: Adding ICD-10 version format below****************;
    PROC FORMAT;
      VALUE $ICD10CF
       /* Myocardial infraction */
        "I21  "-"I22.9",
        "I25.2"  = "MI"
       /* Congestive heart disease */
         "I50  "-"I50.999" = "CHD"
       /* Peripheral vascular disorder */
        "I70  "-"I71.9",
        "I73.01 ",
        "I73.1",
        "I73.9",
        "I79.0",
        "I96",
        "Z95.8"-"Z95.9" = "PVD"
       /* Cerebrovascular disease */
            "G45  "-"G46.999",
        "I60  "-"I69.999" = "CVD"
       /* Dementia */
        "F00  "-"F03.999",
        "F05  "- "F05.999" = "DEM"
       /* Chronic pulmonary disease */
        "J40  "-"J47.999",
        "J60  "-"J67.999",
        "J68.4" =  "CPD"
       /* Rheumatologic disease */
        "M05  "-"M06.999",
        "M32  "-"M34.999",
        "M35.3" = "RHD"
       /* Peptic ulcer disease */
        "K25  "-"K28.999",
        "K56.60 " = "PUD"
       /* Mild liver disease */
        "K70.0"-"K70.31",
        "K73  "-"K74.999",
        "K75.4  " = "MLIVD"
       /* Diabetes */
        "E10.10 "-"E10.11 ",
        "E10.51 "-"E10.52 ",
        "E10.59 ",
        "E10.641",
        "E10.65 ",
        "E10.69 ",
        "E10.9  ",
        "E11.00 "-"E11.01 ",
        "E11.51 "-"E11.52 ",
        "E11.59 ",
        "E11.641",
        "E11.65 ",
        "E11.69 ",
        "E11.9  ",
        "E13.00 "-"E13.01 ",
        "E13.10 "-"E13.11 ",
        "E13.51 "-"E13.52 ",
        "E13.59 ",
        "E13.641",
        "E13.9  " = "DIAB"
       /* Diabetes with chronic complications */
        "E10.2 "-"E10.5",
        "E10.61 "-"E10.619",
        "E11.2 "-"E11.5",
        "E11.61 "-"E11.619",
        "E13.2 "-"E13.5",
        "E13.61 "-"E13.619"= "DIABC "
       /* Hemiplegia or paraplegia */
        "G04.1",
        "G81  "-"G82.999" = "PLEGIA"
       /* Renal Disease */
        "N03.0  "-"N03.9  ",
        "N05.2  "-"N05.5  ",
        "N05.9  ",
        "N06.2  "-"N06.5  ",
        "N07.2  "-"N07.5  ",
        "N08    ",
        "N17.1  "-"N17.2  ",
        "N18.1  "-"N18.6  ",
        "N18.9  ",
        "N19    ",
        "N25.0  ",
        "N25.1  ",
        "N25.81 ",
        "N25.89 ",
        "N25.9  " = "REN"
       /*Malignancy, including leukemia and lymphoma */
        "C00  "-"C26.999",
        "C30  "-"C34.999",
        "C37  "-"C41.999",
        "C43  "-"C43.999",
        "C45  "-"C45.7 ",
        "C46  "-"C58.999",
        "C60  "-"C76.999",
        "C81  "-"C85.999",
        "C86  "-"C86.999",
        "C88  "-"C88.999",
        "C90  "-"C97.999",
        "D03.0  ",
        "D03.10 "-"D03.12 ",
        "D03.20 "-"D03.22 ",
        "D03.30 ",
        "D03.39 ",
        "D03.4  ",
        "D03.51 "-"D03.52 ",
        "D03.59 ",
        "D03.60 "-"D03.62 ",
        "D03.70 "-"D03.72 ",
        "D03.8  ",
        "D03.9  ",
        "D45    " = "MALIGN"
       /* Moderate or severe liver disease */
        "I85.00 "-"I85.01 ",
        "I85.10 "-"I85.11 ",
        "K70.41 ",
        "K71.11 "-"K72.01 ",
        "K72.10 "-"K72.11 ",
        "K72.90 "-"K72.91 ",
        "K76.6  "-"K76.7  "  = "SLIVD"
       /* Metastatic solid tumor */
        "C45.9  ",
        "C77  "-"C80.999"  = "MST"
       /* AIDS */
        "B20  "-"B20.999" = "AIDS"
       /* Other */
          other   = "other"
     ;
   ** TODO: character formats w/ranges make me nervous--this should be vetted against a lookup dataset. ;
      VALUE $ICD9CF
       /* Myocardial infraction */
        "410   "-"410.92",
        "412   " = "MI"
       /* Congestive heart disease */
        "428   "-"428.9 " = "CHD"
       /* Peripheral vascular disorder */
        "440.20"-"440.24",
        "440.31"-"440.32",
        "440.8 ",
        "440.9 ",
        "443.9 ",
        "441   "-"441.9 ",
        "785.4 ",
        "V43.4 ",
        "v43.4 " = "PVD"
       /* Cerebrovascular disease */
           "430   "-"438.9 " = "CVD"
       /* Dementia */
        "290   "-"290.9 " = "DEM"
       /* Chronic pulmonary disease */
        "490   "-"496   ",
        "500   "-"505   ",
        "506.4 " =  "CPD"
       /* Rheumatologic disease */
        "710.0 ",
         "710.1 ",
          "710.4 ",
         "714.0 "-"714.2 ",
         "714.81",
         "725   " = "RHD"
       /* Peptic ulcer disease */
        "531   "-"534.91" = "PUD"
       /* Mild liver disease */
        "571.2 ",
        "571.5 ",
        "571.6 ",
        "571.4 "-"571.49" = "MLIVD"
       /* Diabetes */
        "250   "-"250.33",
        "250.7 "-"250.73" = "DIAB"
       /* Diabetes with chronic complications */
        "250.4 "-"250.63" = "DIABC"
       /* Hemiplegia or paraplegia */
        "344.1 ",
        "342   "-"342.92" = "PLEGIA"
       /* Renal Disease */
        "582   "-"582.9 ",
        "583   "-"583.7 ",
        "585   "-"586   ",
        "588   "-"588.9 " = "REN"
       /*Malignancy, including leukemia and lymphoma */
        "140   "-"172.9 ",
        "174   "-"195.8 ",
        "200   "-"208.91" = "MALIGN"
       /* Moderate or severe liver disease */
        "572.2 "-"572.8 ",
        "456.0 "-"456.21" = "SLIVD"
       /* Metastatic solid tumor */
        "196   "-"199.1 " = "MST"
       /* AIDS */
        "042   "-"044.9 " = "AIDS"
       /* Other */
          other   = "other"
     ;
   run;

   ** For debugging. ;
   %local sqlopts ;
   %let sqlopts = feedback sortmsg stimer ;
   %**let sqlopts = ;

   *******************************************************************************;
   ** subset to the utilization data of interest (add the people with no visits  *;
   **    back at the end                                                         *;
   *******************************************************************************;


   ***********************************************;
   ** implement the Inpatient and Outpatient Flags;
   *********************************************** ;
  %if       &inpatonly =I %then %let inpatout= AND EncType in ('IP');
  %else %if &inpatonly =B %then %let inpatout= AND EncType in ('IP','AV');
  %else %if &inpatonly =A %then %let inpatout=;
  %else %if &inpatonly =C %then %let inpatout= AND EncType in (&enctype_list);
  %else %do;
   %Put ERROR in Inpatonly flag.;
   %Put Valid values are I for Inpatient and B for both Inpatient and Outpatient (AV), A for All Encounters or C for a custom list (use the enctype_list parameter) ;
  %end;

   proc sql &sqlopts ;

      create table _ppl as
      select MRN, Min(&IndexDateVarName) as &IndexDateVarName format = mmddyy10.
      from &inputds
      group by MRN ;

     %local TotPeople ;
      %let TotPeople = &SQLOBS ;

     alter table _ppl add primary key (MRN) ;

     create table  _DxSubset as
     select sample.mrn
    , &IndexDateVarName
    , adate
    , case dx_codetype when '09' then put(dx, $icd9cf.)
                 when '10' then put (dx, $ICD10CF.)
               else '???' end as CodedDx  /*C001*/
     from &_vdw_dx as d INNER JOIN _ppl as sample
     ON    d.mrn = sample.mrn
     where  adate between sample.&IndexDateVarName-1
                     and sample.&IndexDateVarName-&days_lookback
               &inpatout.
     ;

      * select count(distinct MRN) as DxPeople format = comma.
        label = "No. people having any Dxs w/in a year prior to &IndexDateVarName"
            , (CALCULATED DxPeople / &TotPeople) as PercentWithDx
               format = percent6.2 label = "Percent of total"
      from _DxSubset ;

     create table _PxAssign as
     select distinct p.mrn, 1 as PVD
     from &_vdw_px (where = ( "35355" <= PX <= "35381" or
            PX in ("34201","34203","35454","35456","35459","35470", "38.48", "93668"
                   "35473","35474","35482","35483","35485","35492","35493",
                   "35495","75962","75992"
                   "35521","35533","35541","35546","35548","35549","35551",
                   "35556","35558","35563","35565","35566","35571","35582",
                   "35583","35584","35585","35586","35587","35621","35623",
                   "35641","35646","35647","35651","35654","35656","35661",
                   "35663","35665","35666","35671"
                  '04RK07Z', '04RK0JZ', '04RK0KZ', '04RK47Z', '04RK4JZ',
                  '04RK4KZ', '04RL07Z', '04RL0JZ', '04RL0KZ', '04RL47Z', '04RL4JZ',
                  '04RL4KZ', '04RM07Z', '04RM0JZ', '04RM0KZ', '04RM47Z', '04RM4JZ',
                  '04RM4KZ', '04RN07Z', '04RN0JZ', '04RN0KZ', '04RN47Z', '04RN4JZ',
                  '04RN4KZ', '04RP07Z', '04RP0JZ', '04RP0KZ', '04RP47Z', '04RP4JZ',
                  '04RP4KZ', '04RQ07Z', '04RQ0JZ', '04RQ0KZ', '04RQ47Z', '04RQ4JZ',
                  '04RQ4KZ', '04RR07Z', '04RR0JZ', '04RR0KZ', '04RR47Z', '04RR4JZ',
                  '04RR4KZ', '04RS07Z', '04RS0JZ', '04RS0KZ', '04RS47Z', '04RS4JZ',
                  '04RS4KZ', '04RT07Z', '04RT0JZ', '04RT0KZ', '04RT47Z', '04RT4JZ',
                  '04RT4KZ', '04RU07Z', '04RU0JZ', '04RU0KZ', '04RU47Z', '04RU4JZ',
                  '04RU4KZ', '04RV07Z', '04RV0JZ', '04RV0KZ', '04RV47Z', '04RV4JZ',
                  '04RV4KZ', '04RW07Z', '04RW0JZ', '04RW0KZ', '04RW47Z', '04RW4JZ',
                  '04RW4KZ', '04RY07Z', '04RY0JZ', '04RY0KZ', '04RY47Z', '04RY4JZ',
                  '04RY4KZ'))) as p INNER JOIN
          _ppl as sample
     on   p.mrn = sample.mrn
           where px_codetype in ('C4', 'H4', '09', '10')
           and adate between sample.&IndexDateVarName-1
                         and sample.&IndexDateVarName-&days_lookback
           &inpatout.
     ;

      * select count(distinct MRN) as PxPeople format = comma.
        label = "No. people who had any Pxs w/in a year prior to &IndexDateVarName"
            , (CALCULATED PxPeople / &TotPeople) as PercentWithPx
                format = percent6.2 label = "Percent of total sample"
      from _PxAssign ;

   quit ;

   proc sort data = _DxSubset ;
      by MRN ;
   run ;

   proc sort data = _PxAssign ;
      by MRN ;
   run ;

   /**********************************************/
   /*** Assing DX based flagsts                ***/
   /***                                        ***/
   /***                                        ***/
   /**********************************************/

   %local var_list ;
   %let var_list = MI CHD PVD CVD DEM CPD RHD PUD MLIVD DIAB
                   DIABC PLEGIA REN MALIGN SLIVD MST AIDS ;

   data _DxAssign ;
     length &var_list 3 ;
     retain           &var_list ;
     set _DxSubset;
     by mrn;
     array COMORB (*) &var_list ;
     if first.mrn then do;
        do I=1 to dim(COMORB);
           COMORB(I) = 0 ;
        end;
     end;
     select (CodedDx);
        when ('MI')    MI     = 1;
        when ('CHD')   CHD    = 1;
        when ('PVD')   PVD    = 1;
        when ('CVD')   CVD    = 1;
        when ('DEM')   DEM    = 1;
        when ('CPD')   CPD    = 1;
        when ('RHD')   RHD    = 1;
        when ('PUD')   PUD    = 1;
        when ('MLIVD') MLIVD  = 1;
        when ('DIAB')  DIAB   = 1;
        when ('DIABC') DIABC  = 1;
        when ('PLEGIA')PLEGIA = 1;
        when ('REN')   REN    = 1;
        when ('MALIGN')MALIGN = 1;
        when ('SLIVD') SLIVD  = 1;
        when ('MST')   MST    = 1;
        when ('AIDS')  AIDS   = 1;
        otherwise ;
     end;
     if last.mrn then output;
     keep   mrn  &var_list ;
   run;

   /** Connect DXs and PROCs together  **/
   proc sql &sqlopts ;
     ** Adding a bunch of coalesces here in case there are ppl w/procs but no dxs. ;
     create table _DxPxAssign as
      select  coalesce(D.MRN, P.MRN) as MRN
            , coalesce(D.MI    , 0)  as MI
            , coalesce(D.CHD   , 0)  as CHD
            , coalesce(D.CVD   , 0)  as CVD
            , coalesce(D.DEM   , 0)  as DEM
            , coalesce(D.CPD   , 0)  as CPD
            , coalesce(D.RHD   , 0)  as RHD
            , coalesce(D.PUD   , 0)  as PUD
            , coalesce(D.MLIVD , 0)  as MLIVD
            , coalesce(D.DIAB  , 0)  as DIAB
            , coalesce(D.DIABC , 0)  as DIABC
            , coalesce(D.PLEGIA, 0)  as PLEGIA
            , coalesce(D.REN   , 0)  as REN
            , coalesce(D.MALIGN, 0)  as MALIGN
            , coalesce(D.SLIVD , 0)  as SLIVD
            , coalesce(D.MST   , 0)  as MST
            , coalesce(D.AIDS  , 0)  as AIDS
            , max(D.PVD, P.PVD)      as PVD
      from  WORK._DXASSIGN as D full outer join
            WORK._PXASSIGN P
      on    D.MRN = P.MRN
      ;
   quit ;

   *****************************************************;
   * Assign the weights and compute the index
   *****************************************************;

   Data _WithCharlson;
     set _DxPxAssign;
     M1=1;M2=1;M3=1;

   ** implement the MALIG flag;
            %if &malig =N %then %do; O1=1; O2=1; %end;
      %else %if &malig =Y %then %do; O1=0; O2=0; %end;
      %else %do;
        %Put ERROR in MALIG flag.  Valid values are Y (Cancer study. Zero weight;
        %Put ERROR the cancer vars)  and N (treat cancer normally);
      %end;

     if SLIVD = 1 then M1=0;
     if DIABC = 1 then M2=0;
     if MST   = 1 then M3=0;


   &IndexVarName =   sum(MI , CHD , PVD , CVD , DEM , CPD , RHD ,
                     PUD , M1*MLIVD , M2*DIAB , 2*DIABC , 2*PLEGIA , 2*REN ,
                     O1*2*M3*MALIGN , 3*SLIVD , O2*6*MST , 6*AIDS) ;

   Label
     MI            = "Myocardial Infarction: "
     CHD           = "Congestive heart disease: "
     PVD           = "Peripheral vascular disorder: "
     CVD           = "Cerebrovascular disease: "
     DEM           = "Dementia: "
     CPD           = "Chronic pulmonary disease: "
     RHD           = "Rheumatologic disease: "
     PUD           = "Peptic ulcer disease: "
     MLIVD         = "Mild liver disease: "
     DIAB          = "Diabetes: "
     DIABC         = "Diabetes with chronic complications: "
     PLEGIA        = "Hemiplegia or paraplegia: "
     REN           = "Renal Disease: "
     MALIGN        = "Malignancy, including leukemia and lymphoma: "
     SLIVD         = "Moderate or severe liver disease: "
     MST           = "Metastatic solid tumor: "
     AIDS          = "AIDS: "
     &IndexVarName = "Charlson score: "
   ;

   keep MRN &var_list &IndexVarName ;

   run;

   /* add the people with no visits back in, and create the final dataset */
   /* people with no visits or no comorbidity DXs have all vars set to zero */

   proc sql &sqlopts ;
     create table &outputds as
     select distinct i.MRN
         , i.&IndexDateVarName
         , coalesce(w.MI           , 0) as  MI
                      label = "Myocardial Infarction: "
         , coalesce(w.CHD          , 0) as  CHD
                      label = "Congestive heart disease: "
         , coalesce(w.PVD          , 0) as  PVD
                      label = "Peripheral vascular disorder: "
         , coalesce(w.CVD          , 0) as  CVD
                      label = "Cerebrovascular disease: "
         , coalesce(w.DEM          , 0) as  DEM
                      label = "Dementia: "
         , coalesce(w.CPD          , 0) as  CPD
                      label = "Chronic pulmonary disease: "
         , coalesce(w.RHD          , 0) as  RHD
                      label = "Rheumatologic disease: "
         , coalesce(w.PUD          , 0) as  PUD
                      label = "Peptic ulcer disease: "
         , coalesce(w.MLIVD        , 0) as  MLIVD
                      label = "Mild liver disease: "
         , coalesce(w.DIAB         , 0) as  DIAB
                      label = "Diabetes: "
         , coalesce(w.DIABC        , 0) as  DIABC
                      label = "Diabetes with chronic complications: "
         , coalesce(w.PLEGIA       , 0) as  PLEGIA
                      label = "Hemiplegia or paraplegia: "
         , coalesce(w.REN          , 0) as  REN
                      label = "Renal Disease: "
         , coalesce(w.MALIGN       , 0) as  MALIGN
                      label = "Malignancy, including leukemia and lymphoma: "
         , coalesce(w.SLIVD        , 0) as  SLIVD
                      label = "Moderate or severe liver disease: "
         , coalesce(w.MST          , 0) as  MST
                      label = "Metastatic solid tumor: "
         , coalesce(w.AIDS         , 0) as  AIDS
                      label = "AIDS: "
         %if %upcase(&NoEncounterGetsMissing) = Y %then %do ;
           , w.&IndexVarName
         %end ;
         %else %do ;
           , coalesce(w.&IndexVarName, 0) as &IndexVarName
         %end ;
          label = "Charlson score: "
         , (w.MRN is null)              as  NoVisitFlag
                      label = "No diagnoses or procedures found in the year prior to &IndexDateVarName for this person"
     from _ppl as i left join _WithCharlson as w
     on i.MRN = w.MRN
     ;

  /* clean up work sas datasets */
  proc datasets nolist ;
    delete _DxSubset
           _PxSubset
           _DxAssign
           _PxAssign
           _DxPxAssign
           _WithCharlson
           _NoVisit
           _ppl
           ;
  quit ;
%mend charlson;
