      ******************************************************************
      * Copyright Core DF
      *
      * Licensed under the Apache License, Version 2.0 (the "License");
      * you may not use this file except in compliance with the License.
      * You may obtain a copy of the License at
      *
      *     http://www.apache.org/licenses/LICENSE-2.0
      *
      * Unless required by applicable law or agreed to in writing, software
      * distributed under the License is distributed on an "AS IS" BASIS,
      * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
      * See the License for the specific language governing permissions and
      * limitations under the License.
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
