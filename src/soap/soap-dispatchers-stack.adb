------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                         Copyright (C) 2016, CNRS                         --
--                                                                          --
--  This library is free software;  you can redistribute it and/or modify   --
--  it under terms of the  GNU General Public License  as published by the  --
--  Free Software  Foundation;  either version 3,  or (at your  option) any --
--  later version. This library is distributed in the hope that it will be  --
--  useful, but WITHOUT ANY WARRANTY;  without even the implied warranty of --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                    --
--                                                                          --
--  As a special exception under Section 7 of GPL version 3, you are        --
--  granted additional permissions described in the GCC Runtime Library     --
--  Exception, version 3.1, as published by the Free Software Foundation.   --
--                                                                          --
--  You should have received a copy of the GNU General Public License and   --
--  a copy of the GCC Runtime Library Exception along with this program;    --
--  see the files COPYING3 and COPYING.RUNTIME respectively.  If not, see   --
--  <http://www.gnu.org/licenses/>.                                         --
--                                                                          --
--  As a special exception, if other files instantiate generics from this   --
--  unit, or you link this unit with other files to produce an executable,  --
--  this  unit  does not  by itself cause  the resulting executable to be   --
--  covered by the GNU General Public License. This exception does not      --
--  however invalidate any other reasons why the executable file  might be  --
--  covered by the  GNU Public License.                                     --
------------------------------------------------------------------------------

with Ada.Strings.Unbounded;

with AWS.Messages;
with SOAP.Message.XML;

package body SOAP.Dispatchers.Stack is

   use Ada.Strings.Unbounded;

   overriding function Callback (Object : in out Item;
                                 Request : AWS.Status.Data)
                                return AWS.Response.Data is
   begin
      if AWS.Status.Is_SOAP (Request) then
         declare
            SOAPAction : constant String := AWS.Status.SOAPAction (Request);
         begin
            return Object.SOAP_Callback
              (SOAPAction,
               SOAP.Message.XML.Load_Payload
                 (Unbounded_String'(AWS.Status.Payload (Request)),
                  Schema => Schema (Item'Class (Object), SOAPAction)),
               Request);
         end;
      else
         return AWS.Response.Acknowledge
           (AWS.Messages.S404,
            "<p>Request not handled by callback</p>");
      end if;
   end Callback;

   function Create (Callback : Dispatchers.SOAP_Callback)
                   return AWS.Services.Dispatchers.Stack.Item_Interface'Class
   is
   begin
      return Item'(Schema => SOAP.WSDL.Schema.Empty,
                   SOAP_Callback => Callback);
   end Create;

   function Schema
     (Object     : Item;
      SOAPAction : String)
     return WSDL.Schema.Definition is
      pragma Unreferenced (SOAPAction);
   begin
      return Object.Schema;
   end Schema;

end SOAP.Dispatchers.Stack;