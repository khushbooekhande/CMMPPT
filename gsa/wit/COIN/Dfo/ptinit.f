C Copyright (C) 2000, International Business Machines
C Corporation and others.  All Rights Reserved.
      SUBROUTINE PTINIT(N     , X     , LDX   , FX    , NX    , NP0   , 
     +                  NF    , POLY  , POINTS, VALUES, PNTINT, VALINT,
     +                  SP2IN , IN2SP , NIND  , BASE  , DIST  , DELTA ,   
     +                  DELMAX, PIVTHR, PIVVAL, LB    , UB    , A     ,
     +                  LDA   , LDCJ  , NCLIN , NCNLN , SCALE , SCAL  , 
     +                  WRK   , LWRK  , IWRK  , LIWRK , INFORM, NEQCON)


C
C  ******************************************************************
C  THIS SUBROUTINE BUILDS THE INITIAL INTERPOLATION SET.
C  GIVEN ONE STARTING POINT AND A TOTAL NUMBER OF POINT
C  IN INITIAL MODEL (NP0 - SPECIFIED BY THE USER) ADDITIONAL
C  POINTS ARE CONSTRUCTED IN SOME NEIGHBORHOOD OF THE INITIAL POINT.
C  AT LEAST  2 POINTS ARE NEEDED TO BUILD INITIAL MODEL.
C  AFTER DETERMINING THE POINTS AND THEIR FUNCTION VALUES WE
C  BUILD THE BASIS OF NEWTON FUNDAMENTAL POLYNOMIALS FOR THE
C  INITIAL INTERPOLATION SET
C  
C  PARAMETERS
C
C  N      (INPUT)  PROBLEM DIMENSION
C
C  NP0    (INPUT)  NUMBER OF POINTS REQUIRED FOR INITIAL MODEL BY THE
C                  USER
C         (OUTPUT) NUMBER OF POINTS FOR THE INITIAL MODEL SUPPLIED BY
C                  THE PROGRAM
C
C  X      (INPUT)  ARRAY OF LENGTH LDX*NX CONTAINING THE 'NX 'STARTING
C                  POINTS, PROVIDED BY THE USER.
C         (OUTPUT) CURRENT BEST POINT, POSSIBLY AFTER PROJECTION ONTO 
C                  FEASIBLE SET, IN FIRST N ENTREES
C
C  LDX    (INPUT)  LEADING DIMENSION OF ARRAY X
C
C  FX     (INPUT)  ARRAY OF 'NX' FUNCTION VALUES AT POINTS IN 'X'
C         (OUTPUT) THE BEST CURRENT VALUE, IN THE FIRST ENTREE OF 'FX'
C
C  NX     (INPUT)  NUMBER OF INITIAL POINTS PROVIDED
C
C  DELTA  (INPUT)  TRUST REGION RADIUS
C
C  DELMAX (INPUT)  THE MAXIMUM TRUST REGION RADIUS ALLOWED
C
C  PIVTHR (INPUT)  PIVOT THRESHOLD VALUE
C
C  LB     (INPUT)  ARRAY OF LENGTH N+NCLIN+NCNLN OF LOWER BOUNDS 
C
C  UB     (INPUT)     ''       ''         ''        UPPER   ''
C
C  NCLIN  (INPUT)  NUMBER OF LINEAR ANALYTIC CONSTRAINTS
C
C  A      (INPUT)  (LDA X N) MATRIX OF LINEAR ANALYTIC CONSTRAINTS
C
C  LDA    (INPUT)  LEADING DIMENSION OF MATRIX A 
C                   
C  LDCJ   (INPUT)  LEADING DIMENSION OF THE JACOBIAN OF NONLINEAR
C                   CONSTRAINTS, AS COMPUTED BY THE USER ROUTINE 'FUNCON'
C  
C  NCNLN  (INPUT)  NUMBER OF NONLINEAR INEQUALITIES
C
C  POINTS (OUTPUT) ARRAY (N,NP0) WITH THE POOL OF POTENTIAL INTERPOLATION 
C                  (SAMPLE) POINTS
C
C  VALUE  (OUTPUT)  ARRAY (NP0) OF VALUES AT THE POINTS
C
C  NF     (OUTPUT) NUMBER OF FUNCTION CALLS DONE SO FAR
C
C  BASE   (OUTPUT) INDEX OF THE BASE POINT
C
C  DISTP  (OUTPUT) ARRAY (LVALUE) OF DISTANCES OF POINTS TO THE BASE POINTS
C
C  POLY   (OUTPUT) LONG ARRAY CONTAINING ALL NEWTON FUNDAMENTAL  POLYNOMIALS
C
C  NIND   (OUTPUT) NUMBER OF POINTS INCLUDED IN THE INTERPOLATION
C
C  PNTINT (OUTPUT) ARRAY (N*NIND) OF POINTS INCLUDED IN  THE  INTERPOLATION
C                  IN THE ORDER OF INCLUSION
C  VALINT (OUTPUT) ARRAY (NIND) OF VALUES OF POINTS IN 'PNTINT'
C
C  PIVVAL (OUTPUT) ARRAY (NIND) OF VALUES OF THE PIVOTS PRODUCED IN NBUILD
C
C  SP2IN  (OUTPUT) ARRAY OF 0/1 WHICH INDICATES WHICH POINTS IN "POINTS"
C                  ARE INCLUDED IN THE INTERPOLATION
C  IN2SP  (OUTPUT) ARRAY (NIND) OF INDICES WHICH FOR EVERY POINT IN "PNTINT"
C                  INDICATES ITS POSITION IN "POINTS" 
C
C  WRK             REAL SPACE WORKING ARRAY
C
C  IWRK            INTEGER SPACE WORKING ARRAY
C
C  INFORM (OUTPUT) INFORMATION ON EXIT
C              0    SUCCESSFUL MINIMIZATION
C              1    THE DERIVATIVES OF THE CONSTRAINT OR SOME PARAMETER
C                   SET BY THE USER IS INCORRECT
C              2    PROBLEM IS PROBABLY INFEASIBLE
C             -1    CANNOT COMPUTE FUNCTION VALUE AT ONE OF THE
C                   GENERATED POINTS OR ITS PROJECTION
C  **********************************************************************
C


      DOUBLE PRECISION X(NX*LDX)         , POLY(LPOLY), POINTS(LPNTS) ,
     +                 PNTINT(LPTINT)    , DIST(NP0)  , VALINT(LVLINT), 
     +                 VALUES(LVALUE)    , DELTA      , PIVVAL(LVLINT), 
     +                 UB(N+NCLIN +NCNLN), A(LDA*N)   , SCAL(N)       ,
     +                 LB(N+NCLIN +NCNLN), FX(NX)     , DELMAX        ,
     +                 PIVTHR            , WRK(LWRK)

      INTEGER          N     , NP0   , NF   , SP2IN(NP0), NIND, BASE , 
     +                 LDA   , NCLIN , NCNLN, LWRK      , IWRK, LIWRK,
     +                 INFORM, SCALE , NX   , LDX       , IN2SP(LVLINT),
     +                 NEQCON, LDCJ



C
C  COMMON VARIABLES:
C


C
C  MODEL PARAMETERS
C
      DOUBLE PRECISION GMOD, HMOD
      COMMON /MDLPAR/  GMOD(200), HMOD(200,200)

C
C  LENGTH OF ARRAYS
C

      INTEGER          LPOLY, LPNTS, LVALUE, LPTINT, LVLINT
      COMMON /RPART/   LPOLY, LPNTS, LVALUE, LPTINT, LVLINT

C
C  PRINTOUT PARAMETERS
C
      INTEGER          IOUT  , IPRINT
      DOUBLE PRECISION MCHEPS, CNSTOL 
      COMMON / DFOCM / IOUT  , IPRINT, MCHEPS, CNSTOL

C
C  INTERPOLATION CONTROL PARAMETERS
C      
      INTEGER          NPMIN, LAYER, EFFORT
      COMMON / OPTI /  NPMIN, LAYER, EFFORT

C
C  EXTERNAL ROUTINES
C

      DOUBLE PRECISION DDOT

      EXTERNAL         DDOT

C
C  LOCAL VARIABLES
C

      LOGICAL          IFERR, BDVLTD, INFEAS

      INTEGER          I  , J    , NP , INP, IX, IIX  
      DOUBLE PRECISION VAL, DISTB, DEL, C(1)
     
      DOUBLE PRECISION ZERO, HALF, TWO 

      PARAMETER       ( ZERO=0.0D0, HALF=0.5D0, TWO=2.0D0 )

C
C     SUBROUTINES AND FUNCTIONS CALLED:
C
C       APPLICATION:       MINTR , FUN   , GETDIS, SCL   , UNSCL,
C                          SHIFT , RANLUX, FUNCON, NBUILD
C                           
C                          
C       FORTRAN SUPPLIED:  MIN   , ABS
C       BLAS:              DCOPY , DDOT
C



C  **************************************************************
C  PROCESS THE FIRST POINT, PROVIDED BY THE USER, TO MAKE SURE IT
C  IS INCLUDED IN THE SAMPLE SET
C  **************************************************************


      IFERR  = .FALSE.
      BDVLTD = .FALSE. 
      INFEAS = .FALSE.

C
C  COPY THE POINT IN THE SET OF CURRENT SAMPLE POINTS
C

      CALL DCOPY( N, X, 1, POINTS, 1 )
      VALUES(1)=FX(1)
      VAL = ZERO

C  ****************************************************
C  CHECK FEASIBILITY OF PROVIDED POINT
C  ****************************************************



C
C  CHECK IF THE INITIAL POINT IS FEASIBLE FOR SIMPLE BOUNDS
C  IF IT IS NOT, THEN PROJECT IT ON THE BOUNDS
C

      DO 10 I=1,N
        IF (POINTS(I).LT.LB(I)) THEN
          POINTS(I) = LB(I)
          BDVLTD    = .TRUE.
        ELSEIF (POINTS(I).GT.UB(I)) THEN
          POINTS(I) = UB(I)
          BDVLTD    = .TRUE.
        ENDIF
 10   CONTINUE


C
C  IF PROJECTED, PRINT WARNING MESSAGE 
C
      IF (BDVLTD) THEN
        IF ( IPRINT .GE. 0 ) WRITE(IOUT, 1000)
        CALL DCOPY( N, POINTS, 1, X, 1 ) 
      ENDIF
  
C
C  CHECK FEASIBILITY OF FIRST POINT WRT LINEAR CONSTRAINTS
C

      DO 20 I=1, NCLIN
        VAL=DDOT(N, A(I), LDA, POINTS, 1)
        IF (VAL .GT. UB(N+I) .OR. VAL .LT. LB(N+I)) INFEAS=.TRUE.
 20   CONTINUE
      VAL = ZERO

C
C  ******************************************************************
C  IF THERE ARE NONLINEAR CONSTRAINTS OR IF THE POINT VIOLATES LINEAR 
C  CONSTRAINTS, THEN  PROJECT IT ONTO FEASIBLE SET 
C  (IF IT IS ALREADY FEASIBLE, IS REMAINS THE SAME).
C  IF F_del  DENOTES INTERSECTION OF THE FEASIBLE REGION
C  AND TRUST REGION WITH CENTER AT X_1 AND RADIUS DEL, THEN WE SOLVE
C
C               2
C  MIN ||X-X_1||   S.T. { X IN F_del }
C
C 
C  **********************************************************
C


      DEL=DELTA
      IF ( NCNLN .GT. 0 .OR. INFEAS) THEN
        DO 40 I = 1, N
          GMOD(I)   = -TWO*X( I )
          HMOD(I,I) = TWO
          DO 30 J = I+1, N
            HMOD(I,J) = ZERO
            HMOD(J,I) = ZERO
 30      CONTINUE
 40    CONTINUE
        
C
C  THIS MINIMIZATION PRODUCES PROJECTION OF THE  POINT ONTO
C  FEASIBLE REGION, INTERSECTED WITH TRUST REGION WITH RADIUS DEL
C


C
C  FIND THE PROJECTION
C
 50    CALL MINTR( N   , POINTS, VAL  , DEL  , LB   , UB ,
     *             A   , LDA   , LDCJ , NCLIN, NCNLN, WRK, 
     *             LWRK, IWRK  , LIWRK, INFORM) 

 
        IF ( INFORM .EQ. 1 ) THEN
          IF ( IPRINT .GT. 0 ) WRITE(IOUT,2000)
          RETURN
        ELSEIF (INFORM .EQ. 2) THEN
C
C  IF FEASIBLE SOLUTION WAS NOT FOUND, TRY TO INCREASE 
C  TRUST REGION RADIUS 
C
          IF (DEL .LT. DELMAX) THEN
            DEL=DEL*2
            GOTO 50
          ELSE
C
C  IF THE TRUST REGION RADIUS IS AT IT'S MAXIMUM VALUE
C  THEN ASSUME THE PROBLEM IS INFEASIBLE AND QUIT
C
            IF( IPRINT.GT.0 )   WRITE(IOUT,2010)
            RETURN
          ENDIF
        ENDIF
       
C
C  IF THE POINT HAS CHANGED, THEN THE STARTING POINT IS NOT
C  FEASIBLE AND WE FOUND ITS PROJECTION. PRINT A WARNING.
C
        VAL = ZERO
        DO 60 I = 1, N 
          VAL = VAL + ABS(POINTS(I)-X(I))
 60     CONTINUE
        IF ( IPRINT .GE. 0 ) THEN
          IF (VAL .GT. 100*N*MCHEPS) WRITE(IOUT, 1010)
        ENDIF
      ENDIF

      IF (VAL .GT. 100*N*MCHEPS .OR. BDVLTD) THEN

C
C  COMPUTE FUNCTION VALUE FOR THE FIRST POINT IF IT
C  HAD TO BE PROJECTED. IF SUCH COMPUTATION
C  FAILS, THEN QUIT THE PROGRAM
C
        NF = NF + 1
        IF ( SCALE .NE. 0 ) CALL UNSCL( N, POINTS, SCAL )
        CALL FUN( N, POINTS, VALUES, IFERR )
        IF ( SCALE .NE. 0 ) CALL SCL( N, POINTS, SCAL )
        IF ( IFERR ) THEN
          IF( IPRINT.GT.0 ) WRITE(IOUT,2020)
          INFORM = -1
          RETURN
        ENDIF
      ENDIF

C
C  INITIALIZE POINTERS TO CURRENT SAMPLE POINT (IN 'POINTS')
C
      NP  = 1
      INP = N+1

C
C  CYCLE OVER ALL OTHER POINTS PROVIDED BY USER
C

      DO 120 IX=2, NX
C
C  POINTER TO CURRENT POINT PROVIDED BY USER (IN 'X')
C

        IIX     = (IX-1)*LDX + 1

C
C  COPY THE POINT IN THE SET OF CURRENT SAMPLE POINTS
C

        CALL DCOPY( N, X( IIX ), 1, POINTS( INP ), 1 )


C  ****************************************************
C  CHECK FEASIBILITY OF PROVIDED POINT
C  ****************************************************



C
C  CHECK IF THE INITIAL POINT IS FEASIBLE FOR SIMPLE BOUNDS
C  IF IT IS NOT, SKIP THIS POINT, AND MOVE TO THE NEXT ONE
C  PRINT A WARNING
C

        DO 70 I=1,N
          IF ( POINTS(INP+I-1).LT.LB(I)-CNSTOL .OR. 
     +         POINTS(INP+I-1).GT.UB(I)+CNSTOL ) THEN 
            IF ( IPRINT .GE. 0 ) WRITE(IOUT, 1020) IX
            GO TO 120
          ENDIF
 70     CONTINUE


C
C  CHECK IF THE CURRENT POINT IS FEASIBLE WRT LINEAR CONSTRAINTS
C  IF IT IS NOT, SKIP THIS POINT, AND MOVE TO THE NEXT ONE
C  PRINT A WARNING
C

        DO 80 I=1, NCLIN
          VAL=DDOT(N, A(I), LDA, POINTS(INP), 1)
          IF ( VAL .GT. UB(N+I)+CNSTOL .OR. 
     +         VAL .LT. LB(N+I)-CNSTOL ) THEN
            IF ( IPRINT .GE. 0 ) WRITE(IOUT, 1030) IX
            GO TO 120
          ENDIF
 80    CONTINUE


C
C  CHECK IF THE POINT IS FEASIBLE WRT NONLINEAR CONSTRAINTS
C  BY PROJECTING IT ONTO THE FEASIBLE REGION (SEE HOW IT IS
C  DONE FOR THE FIRST POINT) AND CHECKING IF THE PROJECTION
C  IS DIFFERENT FROM THE POINT
C

        VAL = ZERO
        IF ( NCNLN .GT. 0 ) THEN
          DO 100 I = 1, N
            GMOD(I)   = -TWO*X( IIX + I - 1 )
            HMOD(I,I) = TWO
            DO 90 J = I+1, N
              HMOD(I,J) = ZERO
              HMOD(J,I) = ZERO
 90       CONTINUE
 100    CONTINUE
        
C
C  THIS MINIMIZATION PRODUCES PROJECTION OF THE  POINT ONTO
C  FEASIBLE REGION, INTERSECTED WITH TRUST REGION WITH RADIUS DEL
C


C
C  FIND THE PROJECTION
C
          CALL MINTR( N   , POINTS(INP), VAL  , DEL   , LB   , UB ,
     *                A   , LDA        , LDCJ , NCLIN , NCNLN, WRK,
     *                LWRK, IWRK       , LIWRK, INFORM) 


 
          IF ( INFORM .EQ. 1 ) THEN
            IF ( IPRINT .GT. 0 ) WRITE(IOUT,2000)
            RETURN
          ELSEIF (INFORM .EQ. 2) THEN
C
C  IF NO FEASIBLE SOLUTION WAS FOUND THEN SKIP THIS POINTS AND
C  MOVE TO THE NEXT ONE
C
            IF ( IPRINT .GT. 0 ) WRITE( IOUT, 1040 ) IX
            GO TO 120 
          ENDIF
       
C
C  IF THE POINT HAS CHANGED, THEN THE STARTING POINT IS NOT
C  FEASIBLE, WE SKIP IT AND MOVE TO THE NEXT POINT
C
          VAL = ZERO
          DO 110 I = 1, N 
            VAL = VAL + ABS(POINTS(INP+I-1)-X(IIX+I-1))
 110      CONTINUE
          IF (VAL .GT. 100*N*MCHEPS) THEN
            IF ( IPRINT .GT. 0 ) WRITE(IOUT, 1040) IX
            GO TO 120
          ENDIF
        ENDIF
C
C  IF THE POINT PASSED ALL FEASIBILITY TESTS, THEN ACCEPT IT AS
C  A SAMPLE POINT AND RECORD ITS FUNCTION VALUE
C
        NP           = NP  + 1
        INP          = INP + N
        VALUES( NP ) = FX ( IX )

 120  CONTINUE  

      NP0 = NP

C  --------------------------------------------------------------
C
C  IF THERE IS ONLY ONE POINT IN THE SAMPLE SET, TRY TO FIND ANOTHER
C
C  --------------------------------------------------------------


C
C  GENERATE A POINT RANDOMLY WITHIN DELTA DISTANCE FROM X
C  AND SATISFYING THE SIMPLE BOUNDS
C  WRITE  THE POINT IN ARRAY 'POINTS'
C

      IF ( NP0 .EQ. 1 ) THEN
        IF ( IPRINT .GE. 2 ) WRITE( IOUT, 8000 ) 
        CALL DCOPY( N, POINTS, 1, X, 1 )
C
C  GENERATE N RANDOM NUMBERS BETWEEN 0 AND 1 AND RECORD THEM TO
C  POINTS STARTING FROM N+1-ST ENTREE
C       

        CALL RANLUX(POINTS(N+1), N)
        DO 130 J = 1, N
          DISTB=ZERO
          DISTB=MIN(DELTA, UB(J)-X(J))
          IF (DISTB.GT.MCHEPS) THEN
            POINTS( N + J ) = DISTB * POINTS(N+J) + X( J )
          ENDIF 
          IF (DISTB.LE.MCHEPS) THEN
            DISTB=MIN(DELTA, X(J)-LB(J))
            POINTS( N + J ) = -DISTB * POINTS(N+J) + X( J ) 
          ENDIF
 130   CONTINUE

C
C  CHECK FEASIBILITY OF AUXILIARY POINT WRT LINEAR CONSTRAINTS
C
        INFEAS = .FALSE.
        DO 140 I=1, NCLIN
          VAL=DDOT(N, A(I), LDA, POINTS(N+1), 1)
          IF (VAL .GT. UB(N+I) .OR. VAL .LT. LB(N+I)) INFEAS = .TRUE.
 140    CONTINUE
        VAL = ZERO
C  -------------------------------------------------------
C  FIND THE SECOND POINT FOR INTERPOLATION
C  -------------------------------------------------------

        IF ( NCNLN .GT. 0 .OR. INFEAS) THEN          
          DO 160 I = 1, N
            GMOD(I)   = -TWO*POINTS(N+I)
            HMOD(I,I) =  TWO
            DO 150 J = I+1, N
              HMOD(I,J) = ZERO
              HMOD(J,I) = ZERO
 150        CONTINUE
 160      CONTINUE
        
        
          CALL MINTR ( N   , X    , VAL  , DELTA, LB   , UB ,
     *                 A   , LDA  , LDCJ , NCLIN, NCNLN, WRK, 
     *                 LWRK, IWRK , LIWRK, INFORM) 
 
          IF (INFORM .EQ. 1) THEN
            IF( IPRINT.GT.0 )   WRITE(IOUT,2000)
            RETURN
          ELSEIF (INFORM .EQ. 2) THEN
            IF( IPRINT.GT.0 )   WRITE(IOUT,2010)
            RETURN
          ENDIF


C  -------------------------------------------------------
C  IF FIRST AND SECOND POINTS COINCIDE, FIND A DIFFERENT SECOND POINT
C  -------------------------------------------------------

          VAL = ZERO
          DO 170 I = 1, N 
            VAL = VAL + ABS(X(I)-POINTS(I))
 170      CONTINUE

          IF (VAL .LT. 10*N*PIVTHR) THEN
            DO 190 I = 1, N
              GMOD(I)   =  TWO*POINTS(N+I)
              HMOD(I,I) = -TWO
              DO 180 J = I+1, N
                HMOD(I,J) = ZERO
                HMOD(J,I) = ZERO
 180          CONTINUE
 190        CONTINUE


            CALL MINTR ( N   , X    , VAL  , DEL   , LB   , UB ,
     *                   A   , LDA  , LDCJ , NCLIN , NCNLN, WRK,
     *                   LWRK, IWRK , LIWRK, INFORM ) 
  
            IF ( INFORM .EQ. 1 ) THEN
              IF( IPRINT.GT.3 )   WRITE(IOUT,2000)
              RETURN
            ELSEIF ( INFORM .EQ. 2 ) THEN
              IF( IPRINT.GT.3 )   WRITE(IOUT,2010)
              RETURN
            ENDIF 
          ENDIF
          CALL DCOPY ( N, X, 1, POINTS(N+1), 1 )
        ENDIF

C  --------------------------------------------------------------
C
C  INTERPOLATION POINTS ARE COMPUTED
C
C  --------------------------------------------------------------




C
C  COMPUTE FUNCTION VALUE FOR THE  AUXILIARY  POINT. 
C  IF THERE ARE NONLINEAR CONSTRAINS, AND  IF FUNCTION EVALUATION 
C  FAILS FOR THE AUXILIARY  POINT, WE QUIT.
C  IF THERE ARE NO NONLINEAR CONSTRAINTS, THEN IF FUNCTION EVALUATION
C  FAILS FOR AUXILIARY POINT, WE SUBSTITUTE IT BY ITS CONVEX
C  COMBINATION WITH THE FIRST POINT:
C
C     X_k <-- 1/2(X_k+X_1)
C


 200    IF ( SCALE .NE. 0 ) CALL UNSCL( N, POINTS( N+1 ), SCAL )
        CALL FUN( N, POINTS( N+1 ), VALUES( 2 ), IFERR )
        IF ( SCALE .NE. 0 ) CALL SCL( N, POINTS( N+1 ), SCAL )
        NF = NF + 1 
        IF ( IFERR ) THEN
          DO 210 J = 1, N
            POINTS(N+J) = HALF*(POINTS(J) + POINTS(N+J))
 210      CONTINUE
C
C  IF THE SECOND POINT GETS TOO CLOSE TO FIRST POINT, QUIT
C
          CALL GETDIS( N, 2, 2, POINTS, 1, DIST, WRK, LWRK ) 
          IF ( DIST(2) .LT. PIVTHR ) THEN  
            INFORM = -1
            RETURN 
          ENDIF
C
C  IF THE SECOND POINTS BECOMES NON-FEASIBLE, QUIT
C
          IF ( NCNLN.GT. 0 ) THEN 
            CALL FUNCON(1  , NCNLN , N  , LDCJ , IWRK,
     *                  POINTS(N+1), WRK, WRK(NCNLN+1), 1  )
            DO 220 J=1, NCNLN 
              IF ( WRK(J) .LT. LB(N+NCLIN+J) - CNSTOL .OR.
     *             WRK(J) .GT. UB(N+NCLIN+J) + CNSTOL     ) THEN
                INFORM = -1
                RETURN 
              ENDIF
 220        CONTINUE
          ENDIF  
          GOTO 200
        ENDIF
C
C  SET THE NUMBER OF SAMPLE POINTS TO EQUAL 2
C
        NP0 = 2
      ENDIF

C
C  CHOOSE THE BASE POINT
C
      BASE = 1
      DO 230 I=1, NP0
        IF ( VALUES(I) .LT. VALUES(BASE) + 1.0D2*MCHEPS ) BASE=I
 230  CONTINUE
C
C  COPY THE BASE POINT INTO X
C

      CALL DCOPY(N, POINTS((BASE-1)*N+1), 1, X, 1)
C
C  THE MAXIMUM POSSIBLE NUMBER OF INDEPENDENT INTERPOLATION POINTS
C  DEPENDS ON THE ACTUAL DIMENSION OF THE FEASIBLE SET, RATHER THEN
C  ON THE DIMENSION OF THE WHOLE SPACE. SUBROUTINE 'INTDIM' COMPUTES
C  THE DIMENSION OF THE SPACE SPANNED BY EQUALITY CONSTRAINTS AT
C  THE BASE. WE CONSIDER A CONSTRAINT AS  EQUALITY IF THE DIFFERENCE
C  BETWEEN ITS UPPER AND LOWER BOUNDS IS LESS THAN PIVOT THRESHOLD
C
C  NEQCON - NUMBER OF LINEARLY INDEPENDENT EQUALITY CONSTRAINTS
C


      CALL INTDIM( X    , N , NCLIN, NCNLN , NEQCON, A   , LDA , 
     +             LDCJ , LB, UB   , PIVTHR, WRK   , LWRK, IWRK,
     +             LIWRK)
  
C  
C  THE BASE IS CHOSEN, SHIFT THE POINTS SO THAT THE BASE IS AT THE ORIGIN
C      
      DO 240 I=1,NP0
        CALL SHIFT(N, X, POINTS((I-1)*N+1))
 240  CONTINUE



C
C  GET THE DISTANCES OF ALL POINTS IN 'POINTS' TO THE BASE
C

      CALL GETDIS( N, NP0, 0, POINTS, BASE, DIST, WRK, LWRK)
     
C
C  CHECK IF ANY OF THE POINTS ARE TOO FAR, AND WOULD NOT BE INCLUDED
C  IN INTERPOLATION SET
C
      BDVLTD = .FALSE.
      DO 250 I = 1, NP0
        IF ( DIST(I) .GT. LAYER*DELTA ) BDVLTD = .TRUE.
 250  CONTINUE
      IF ( BDVLTD ) THEN
        IF ( IPRINT .GE. 0 ) WRITE(IOUT,1050)
      ENDIF

C  ---------------------------------------------------------------------
C  COMPUTE THE BASIS OF NEWTON FUNDAMENTAL POLYNOMIALS
C  ---------------------------------------------------------------------

      IF ( BASE .EQ. 1 ) THEN
        CALL DCOPY (N, POINTS, 1, PNTINT, 1)
        VALINT(1) = VALUES(1)
      ENDIF
      IN2SP(BASE)=BASE

      CALL NBUILD( POLY   , POINTS, VALUES, PNTINT, VALINT, SP2IN,
     +             IN2SP  , NIND  , N     , BASE  , DIST  , DELTA, 
     +             PIVTHR , PIVVAL, NEQCON )

      INFORM = 0
      RETURN 

1000  FORMAT(' WARNING: THE FIRST INITIAL POINT IS OUT OF BOUNDS', /
     +             10X, 'IT WILL BE PROJECTED ON THESE BOUNDS',/)
1010  FORMAT(' WARNING: THE FIRST INITIAL POINT IS NOT FEASIBLE', /
     +             10X, 'IT WILL BE PROJECTED ON THE FEASIBLE SET',/)
1020  FORMAT(' WARNING: THE ', I4,'-TH INITIAL POINT IS OUT OF BOUNDS',/
     +             10X, 'IT WILL BE IGNORED',/)
1030  FORMAT(' WARNING: THE ', I4,'-TH INITIAL POINT DOES NOT SATISFY',/
     +             10X, 'LINEAR CONSTRAINTS, IT WILL BE IGNORED',/)
1040  FORMAT(' WARNING: THE ', I4,'-TH INITIAL POINT IS NOT FEASIBLE',/
     +             10X, 'IT WILL BE IGNORED',/)
1050  FORMAT(' WARNING: AT LEAST ONE  INITIAL POINT IS TOO FAR FROM',/
     +       ' THE BASE, IT WILL NOT BE IN THE INTERPOLATION SET ',/
     +       ' TO INCLUDE IT, INCREASE PARAMETER DELTA OR LAYER',/)      
2000  FORMAT(' SOME PARAMETER IN THE PROBLEM FORMULATION ',/
     +       ' HAS ILLEGAL VALUE OR DERIVATIVES OF THE CONSTRAINTS'/
     +       ' ARE WRONG. THE PROGRAM WILL STOP',/)
2010  FORMAT( ' FEASIBLE SET SEEMS TO BE EMPTY ',/
     +        ' THE PROGRAM WILL STOP',/)
2020  FORMAT( ' FUNCTION VALUE WAS NOT FOUND FOR INITIAL POINT',/
     +        ' OR ITS PROJECTION. THE PROGRAM WILL STOP',/)
2030  FORMAT( ' FUNCTION VALUE WAS NOT FOUND FOR AN AUXILIARY POINT.',/
     +        ' THE PROGRAM WILL STOP',/)
8000  FORMAT( ' PTINIT: Getting an auxiliary point '/ )
      END




