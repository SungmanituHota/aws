------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                         Copyright (C) 2000-2001                          --
--                                ACT-Europe                                --
--                                                                          --
--  Authors: Dmitriy Anisimkov - Pascal Obry                                --
--                                                                          --
--  This library is free software; you can redistribute it and/or modify    --
--  it under the terms of the GNU General Public License as published by    --
--  the Free Software Foundation; either version 2 of the License, or (at   --
--  your option) any later version.                                         --
--                                                                          --
--  This library is distributed in the hope that it will be useful, but     --
--  WITHOUT ANY WARRANTY; without even the implied warranty of              --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU       --
--  General Public License for more details.                                --
--                                                                          --
--  You should have received a copy of the GNU General Public License       --
--  along with this library; if not, write to the Free Software Foundation, --
--  Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.          --
--                                                                          --
--  As a special exception, if other files instantiate generics from this   --
--  unit, or you link this unit with other files to produce an executable,  --
--  this  unit  does not  by itself cause  the resulting executable to be   --
--  covered by the GNU General Public License. This exception does not      --
--  however invalidate any other reasons why the executable file  might be  --
--  covered by the  GNU Public License.                                     --
------------------------------------------------------------------------------

--  $Id$

--  Usage: agent [options] [GET/PUT] <URL>
--         -f                      force display of message body.
--         -o                      output result in file agent.out.
--         -k                      keep-alive connection.
--         -s                      server-push mode.
--         -r                      follow redirection.
--         -n                      non stop for stress test.
--         -d                      debug mode, view HTTP headers.
--         -proxy <proxy_url>
--         -u <user_name>
--         -p <password>
--         -a <www_authentication_mode (Any, Basic or Digest)>
--         -pu <proxy_user_name>
--         -pp <proxy_password>
--         -pa <proxy_authentication_mode (Any, Basic or Digest)>
--
--  for example:
--
--     agent GET http://perso.wanadoo.fr/pascal.obry/contrib.html
--

with Ada.Text_IO;
with Ada.Strings.Unbounded;
with Ada.Command_Line;
with Ada.Characters.Handling;
with Ada.Streams.Stream_IO;
with Ada.Exceptions;

with GNAT.Command_Line;

with AWS.Client;
with AWS.Response;
with AWS.Messages;
with AWS.MIME;
with AWS.Status;
with AWS.Translator;

procedure Agent is

   use AWS;
   use Ada;
   use Ada.Strings.Unbounded;
   use type Status.Request_Method;
   use type Messages.Status_Code;

   Syntax_Error : exception;

   Method             : Status.Request_Method;
   User               : Unbounded_String;
   Pwd                : Unbounded_String;
   WWW_Auth           : Client.Authentication_Mode := Client.Basic;
   URL                : Unbounded_String;
   Proxy              : Unbounded_String;
   Proxy_User         : Unbounded_String;
   Proxy_Pwd          : Unbounded_String;
   Proxy_Auth         : Client.Authentication_Mode := Client.Basic;
   Force              : Boolean := False;
   File               : Boolean := False;
   Keep_Alive         : Boolean := False;
   Server_Push        : Boolean := False;
   Follow_Redirection : Boolean := False;
   Wait_Key           : Boolean := True;
   Connect            : AWS.Client.HTTP_Connection;

   procedure Parse_Command_Line;
   --  parse Agent command line.

   function Get_Auth_Mode (Mode : String) return Client.Authentication_Mode;
   --  Return the authentication value from the string representation.
   --  raises the human readable exception on error.

   -------------------
   -- Get_Auth_Mode --
   -------------------

   function Get_Auth_Mode (Mode : String) return Client.Authentication_Mode is
   begin
      return Client.Authentication_Mode'Value (Mode);
   exception
      when Constraint_Error =>
         Ada.Exceptions.Raise_Exception
           (Constraint_Error'Identity,
            "Authentication mode should be ""Basic"", ""Digest"" or ""Any"".");
   end Get_Auth_Mode;

   ------------------------
   -- Parse_Command_Line --
   ------------------------

   procedure Parse_Command_Line is
   begin
      loop
         case GNAT.Command_Line.Getopt
           ("f o d u: p: a: pu: pp: pa: proxy: k n s r")
         is
            when ASCII.NUL =>
               exit;

            when 'f' =>
               Force := True;

            when 'o' =>
               File := True;

            when 'n' =>
               Wait_Key := False;

            when 'd' =>
               AWS.Client.Set_Debug (On => True);

            when 'k' =>
               Keep_Alive := True;

            when 'r' =>
               Follow_Redirection := True;

            when 's' =>
               Server_Push := True;

            when 'u' =>
               User := To_Unbounded_String (GNAT.Command_Line.Parameter);

            when 'a' =>
               WWW_Auth :=
                  Get_Auth_Mode (GNAT.Command_Line.Parameter);

            when 'p' =>
               if GNAT.Command_Line.Full_Switch = "p" then
                  Pwd := To_Unbounded_String (GNAT.Command_Line.Parameter);

               elsif GNAT.Command_Line.Full_Switch = "pu" then
                  Proxy_User
                    := To_Unbounded_String (GNAT.Command_Line.Parameter);

               elsif GNAT.Command_Line.Full_Switch = "pp" then
                  Proxy_Pwd
                    := To_Unbounded_String (GNAT.Command_Line.Parameter);

               elsif GNAT.Command_Line.Full_Switch = "proxy" then
                  Proxy
                    := To_Unbounded_String (GNAT.Command_Line.Parameter);

               elsif GNAT.Command_Line.Full_Switch = "pa" then
                  Proxy_Auth
                    := Get_Auth_Mode (GNAT.Command_Line.Parameter);
               end if;

            when others =>
               raise Program_Error;         -- cannot occurs!
         end case;
      end loop;

      if Follow_Redirection and then Keep_Alive then
         Exceptions.Raise_Exception
           (Syntax_Error'Identity,
            "Follow redirection and keep-alive mode can't be used together.");
      end if;

      Method := Status.Request_Method'Value (GNAT.Command_Line.Get_Argument);
      URL    := To_Unbounded_String (GNAT.Command_Line.Get_Argument);
   end Parse_Command_Line;

   Data : Response.Data;

begin

   if Ada.Command_Line.Argument_Count = 0 then
      Text_IO.Put_Line ("Usage: agent [options] [GET/PUT] <URL>");
      Text_IO.Put_Line ("       -f           force display of message body.");
      Text_IO.Put_Line ("       -o           output result in file agent.out");
      Text_IO.Put_Line ("       -k           keep-alive connection.");
      Text_IO.Put_Line ("       -s           server-push mode.");
      Text_IO.Put_Line ("       -n           non stop for stress test.");
      Text_IO.Put_Line ("       -r           follow redirection.");
      Text_IO.Put_Line ("       -d           debug mode, view HTTP headers.");
      Text_IO.Put_Line ("       -proxy <proxy_url>");
      Text_IO.Put_Line ("       -u <user_name>");
      Text_IO.Put_Line ("       -p <password>");
      Text_IO.Put_Line ("       -a <www_authentication_mode"
                          & " (Any, Basic or Digest)>");
      Text_IO.Put_Line ("       -pu <proxy_user_name>");
      Text_IO.Put_Line ("       -pp <proxy_password>");
      Text_IO.Put_Line ("       -pa <proxy_authentication_mode"
                          & " (Any, Basic or Digest)>");
      return;
   end if;

   Parse_Command_Line;

   Client.Create
     (Connection  => Connect,
      Host        => To_String (URL),
      Proxy       => To_String (Proxy),
      Persistent  => Keep_Alive,
      Server_Push => Server_Push);

   Client.Set_WWW_Authentication
     (Connection => Connect,
      User       => To_String (User),
      Pwd        => To_String (Pwd),
      Mode       => WWW_Auth);

   Client.Set_Proxy_Authentication
     (Connection => Connect,
      User       => To_String (Proxy_User),
      Pwd        => To_String (Proxy_Pwd),
      Mode       => Proxy_Auth);

   loop

      if Method = Status.GET then

         if Keep_Alive then
            Client.Get (Connect, Data);
         else
            Data := Client.Get
              (To_String (URL), To_String (User), To_String (Pwd),
               To_String (Proxy),
               To_String (Proxy_User), To_String (Proxy_Pwd),
               Follow_Redirection => Follow_Redirection);
         end if;

      else
         --  ??? PUT just send a simple piece of Data.
         Client.Put (Connection => Connect,
                     Result     => Data,
                     Data       => "Un essai");
      end if;

      Text_IO.Put_Line
        ("Status Code = "
           & Messages.Image (Response.Status_Code (Data))
           & " - "
           & Messages.Reason_Phrase (Response.Status_Code (Data)));

      if Response.Status_Code (Data) = Messages.S301 then
         Text_IO.Put_Line ("New location : " & Response.Location (Data));
      end if;

      if MIME.Is_Text (Response.Content_Type (Data)) then

         if File then
            declare
               F : Text_IO.File_Type;
            begin
               Text_IO.Create (F, Text_IO.Out_File, "agent.out");
               Text_IO.Put_Line (F, Response.Message_Body (Data));
               Text_IO.Close (F);
            end;
         else
            Text_IO.New_Line;
            Text_IO.Put_Line (Response.Message_Body (Data));
         end if;

      else
         Text_IO.Put_Line
           (Messages.Content_Type (Response.Content_Type (Data)));

         Text_IO.Put_Line
           (Messages.Content_Length (Response.Content_Length (Data)));

         if Force or else File then
            --  this is not a text/html body, but output it anyway

            declare
               Message_Body : constant Unbounded_String
                 := Response.Message_Body (Data);
               Len          : constant Natural := Length (Message_Body);
            begin
               if File then
                  declare
                     use Streams;
                     Chunk_Size : constant := 4_096;
                     F          : Streams.Stream_IO.File_Type;
                     K          : Natural;
                     Last       : Positive;
                  begin
                     Stream_IO.Create
                       (F, Stream_IO.Out_File, "agent.out");

                     K := 1;

                     while K <= Len loop
                        Last := Positive'Min (Len, K + Chunk_Size);

                        Stream_IO.Write
                          (F,
                           Translator.To_Stream_Element_Array
                             (Slice (Message_Body, K, Last)));
                        K := Last + 1;
                     end loop;

                     Stream_IO.Close (F);
                  end;

               else
                  for K in 1 .. Len loop
                     declare
                        C : constant Character := Element (Message_Body, K);
                     begin
                        if C = ASCII.CR
                          or else C = ASCII.LF
                          or else not Characters.Handling.Is_Control (C)
                        then
                           Text_IO.Put (C);
                        else
                           Text_IO.Put ('.');
                        end if;
                     end;
                  end loop;
               end if;
            end;

         end if;
      end if;

      if Server_Push then
         loop
            declare
               Line : constant String
                 := Client.Read_Until (Connect, "" & ASCII.LF);
            begin
               exit when Line = "";
               Text_IO.Put (Line);
            end;
         end loop;
      end if;

      if Keep_Alive then
         --  check that the keep alive connection is kept alive
         if Wait_Key then

            Text_IO.Put_Line
              ("Type 'q' to exit, the connection will be closed.");

            Text_IO.Put_Line ("Any other key to retreive again the same URL");

            declare
               Char : Character;
            begin
               Text_IO.Get_Immediate (Char);
               exit when Char = 'q';
            end;
         end if;

      else
         Client.Close (Connect);
         exit;
      end if;

   end loop;

exception
   when SE : Syntax_Error =>
      Text_IO.Put_Line ("Syntax error: " & Exceptions.Exception_Message (SE));

   when E : others =>
      Text_IO.Put_Line (Exceptions.Exception_Information (E));
end Agent;
