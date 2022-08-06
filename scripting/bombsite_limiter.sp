/**
 * Copyright (C) 2022 nofxD
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
 */
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>

public Plugin myinfo =
{
  name = "[CS:GO] Bombsite Limiter", 
  author = "nof", 
  description = "Restrict Bombsite when player amount is low", 
  version = "1.0.2"
};

Handle tim = INVALID_HANDLE;

int bombsiteA = -1;
int bombsiteB = -1;
int counter = 0;

bool lastBombSite = true;

char DeniedSite[8];

public void OnPluginStart()
{
  if (GetEngineVersion() != Engine_CSGO)
  {
    SetFailState("This plugin is designed only for CS:GO.");
  }
  LoadTranslations("bombsite_limiter.phrases");
  
  HookEvent("round_freeze_end", Event_RoundFreezeEnd, EventHookMode_Post);
  HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
  HookEvent("bomb_planted", Event_RoundEnd, EventHookMode_Post);
}

public Action Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
  if (tim != INVALID_HANDLE)
  {
    CloseHandle(tim);
    tim = INVALID_HANDLE;
  }
}

public Action Event_RoundFreezeEnd(Handle event, const char[] name, bool dontBroadcast)
{
  GetBomsitesIndexes();

  if (tim != INVALID_HANDLE)
  {
    CloseHandle(tim);
    tim = INVALID_HANDLE;
  }

  if (bombsiteA != -1)
    AcceptEntityInput(bombsiteA, "Enable");

  if (bombsiteB != -1)
    AcceptEntityInput(bombsiteB, "Enable");
  
  if (bombsiteA != -1 && bombsiteB != -1)
  {
    int PlayersInCT = 0;
    
    if (GameRules_GetProp("m_bWarmupPeriod") != 1)
    {
      for (int i = 1; i <= MaxClients; i++)
      {
        if (IsValidClient(i))
        {
          if (GetClientTeam(i) == CS_TEAM_CT)
          {
            if (++PlayersInCT > 3)
              return Plugin_Continue;
          }
        }
      }
      
      int siteNum = GetRandomInt(1, 2);
      
      if (siteNum == 1)
      {
        if (lastBombSite == true && counter >= 3)
        {
          lastBombSite = false;
          counter = 0;
          Format(DeniedSite, sizeof(DeniedSite), "B");
          AcceptEntityInput(bombsiteA, "Disable");
        }
        else
        {
          lastBombSite = true;
          counter++;
          Format(DeniedSite, sizeof(DeniedSite), "A");
          AcceptEntityInput(bombsiteB, "Disable");
        }
      }
      else
      {
        if (lastBombSite == false && counter >= 3)
        {
          lastBombSite = true;
          counter = 0;
          Format(DeniedSite, sizeof(DeniedSite), "A");
          AcceptEntityInput(bombsiteB, "Disable");
        }
        else
        {
          lastBombSite = false;
          counter++;
          Format(DeniedSite, sizeof(DeniedSite), "B");
          AcceptEntityInput(bombsiteA, "Disable");
        }
      }
      PrintHintTextToAll("%t", "Bombsite Hint", DeniedSite);
      CPrintToChatAll("%t","Bombsite Chat", DeniedSite);
      tim = CreateTimer(60.0, NotificationMessage, _, TIMER_REPEAT); 
    }
  }
  return Plugin_Continue;
}

public Action NotificationMessage(Handle timer)
{
  PrintHintTextToAll("%t", "Bombsite Hint", DeniedSite);
  CPrintToChatAll("%t", "Bombsite Chat", DeniedSite);
}

stock void GetBomsitesIndexes()
{
  int index = -1;
    
  float vecBombsiteCenterA[3];
  float vecBombsiteCenterB[3];
    
  bombsiteA = -1;
  bombsiteB = -1;
  
  index = FindEntityByClassname(index, "cs_player_manager");
  if (index != -1)
  {
    GetEntPropVector(index, Prop_Send, "m_bombsiteCenterA", vecBombsiteCenterA);
    GetEntPropVector(index, Prop_Send, "m_bombsiteCenterB", vecBombsiteCenterB);
  }

  index = -1;
  while ((index = FindEntityByClassname(index, "func_bomb_target")) != -1)
  {
    float vecBombsiteMin[3];
    float vecBombsiteMax[3];
    
    GetEntPropVector(index, Prop_Send, "m_vecMins", vecBombsiteMin);
    GetEntPropVector(index, Prop_Send, "m_vecMaxs", vecBombsiteMax);
    
    if (IsVecBetween(vecBombsiteCenterA, vecBombsiteMin, vecBombsiteMax))
      bombsiteA = index;
    else if (IsVecBetween(vecBombsiteCenterB, vecBombsiteMin, vecBombsiteMax))
      bombsiteB = index;
  }
}

stock bool IsVecBetween(const float vecVector[3], const float vecMin[3], const float vecMax[3])
{
    return ((vecMin[0] <= vecVector[0] <= vecMax[0]) &&
      (vecMin[1] <= vecVector[1] <= vecMax[1]) &&
      (vecMin[2] <= vecVector[2] <= vecMax[2]));
}

stock bool IsValidClient(int client)
{
  if (client <= 0)return false;
  if (client > MaxClients)return false;
  if (!IsClientConnected(client))return false;
  if (IsClientReplay(client))return false;
  if (IsFakeClient(client))return false;
  if (IsClientSourceTV(client))return false;
  return IsClientInGame(client);
}