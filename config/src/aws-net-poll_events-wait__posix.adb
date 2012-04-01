------------------------------------------------------------------------------
--                              Ada Web Server                              --
--                                                                          --
--                     Copyright (C) 2004-2012, AdaCore                     --
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

--  Wait implementation on top of posix select call

separate (AWS.Net.Poll_Events)

procedure Wait
  (Fds : in out Set; Timeout : Timeout_Type; Result : out Integer)
is
   use Interfaces;
   use type OS_Lib.FD_Type;

   type FD_Set_Type is array
     (OS_Lib.nfds_t range 1 .. OS_Lib.FD_SETSIZE) of OS_Lib.FD_Type;
   pragma Convention (C, FD_Set_Type);

   procedure FD_ZERO (Set : in out FD_Set_Type);
   pragma Import (C, FD_ZERO, "__aws_clear_socket_set");

   procedure FD_SET (FD : OS_Lib.FD_Type; Set : in out FD_Set_Type);
   pragma Import (C, FD_SET, "__aws_set_socket_in_set");

   function FD_ISSET (FD : OS_Lib.FD_Type; Set : FD_Set_Type) return C.int;
   pragma Import (C, FD_ISSET, "__aws_is_socket_in_set");

   procedure Poll is new G_Poll (FD_Set_Type, FD_ZERO, FD_SET, FD_ISSET);

begin
   Poll (Fds, Timeout, Result);
end Wait;