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
