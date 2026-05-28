      ******************************************************************
      * Copyright (c) Core DF. All rights reserved.
      *
      * Core Auto cawbs batch step example (GnuCOBOL).
      *
      * Required environment variables:
      *   ENV, CA_ACCESS_CODE, CA_WBS_URL
      ******************************************************************
       IDENTIFICATION DIVISION.
       PROGRAM-ID. CAWBSBATCH.
       ENVIRONMENT DIVISION.
       DATA DIVISION.
       WORKING-STORAGE SECTION.
           COPY "CAWBSWS.cpy".

       PROCEDURE DIVISION.
       MAIN-PARA.
           CALL "CAWBSBATCHINIT" USING CAWBS-STATUS CAWBS-ERROR
           IF CAWBS-STATUS NOT = 200
               DISPLAY "Init failed: " CAWBS-ERROR
               STOP RUN
           END-IF

           MOVE "db_user,db_password" TO CAWBS-KEYLIST
           CALL "CAWBSBATCHGETKS" USING CAWBS-STATUS
                                      CAWBS-KEYLIST
                                      CAWBS-ANSWER
                                      CAWBS-ERROR
           IF CAWBS-STATUS NOT = 200
               DISPLAY "GetKeystore failed: " CAWBS-ERROR
               STOP RUN
           END-IF
           DISPLAY "Keystore: " CAWBS-ANSWER

           STOP RUN.
       END PROGRAM CAWBSBATCH.
