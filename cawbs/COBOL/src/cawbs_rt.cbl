      ******************************************************************
      * Copyright (c) Core DF. All rights reserved.
      *
      * Core Auto cawbs real-time step example (GnuCOBOL).
      *
      * Documentation: https://coreauto.coredf.com/resources
      *
      * Required environment variables:
      *   ENV, ACTIONID, CA_ACCESS_CODE, CA_WBS_URL, STEPNAME
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CAWBSRT.
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
           COPY "CAWBSWS.cpy".

       PROCEDURE DIVISION.
       MAIN-PARA.
           CALL "CAWBSRTINIT" USING CAWBS-STATUS CAWBS-ERROR
           IF CAWBS-STATUS NOT = 200
               DISPLAY "Init failed: " CAWBS-ERROR
               STOP RUN
           END-IF

           CALL "CAWBSRTGETEVENT" USING CAWBS-STATUS
                                       CAWBS-PAYLOAD
                                       CAWBS-ERROR
           IF CAWBS-STATUS NOT = 200
               DISPLAY "GetEventPayload failed: " CAWBS-ERROR
               STOP RUN
           END-IF
           DISPLAY "Event payload: " CAWBS-PAYLOAD

           MOVE '{"status":"ok"}' TO CAWBS-PAYLOAD
           CALL "CAWBSRTPUTSTEP" USING CAWBS-STATUS
                                     CAWBS-PAYLOAD
                                     CAWBS-ERROR
           IF CAWBS-STATUS NOT = 200
               DISPLAY "PutStepPayload failed: " CAWBS-ERROR
               STOP RUN
           END-IF

           STOP RUN.
       END PROGRAM CAWBSRT.
