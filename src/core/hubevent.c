/*
 * uhub - A tiny ADC p2p connection hub
 * Copyright (C) 2007-2010, Jan Vidar Krey
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#include "uhub.h"
#include "plugin_api/handle.h"

#ifndef PLUGIN_SUPPORT
static void log_user_login(struct hub_user* u)
{
	const char* cred = auth_cred_to_string(u->credentials);
	const char* addr = user_get_address(u);
	LOG_USER("LoginOK     %s/%s %s \"%s\" (%s) \"%s\"", sid_to_string(u->id.sid), u->id.cid, addr, u->id.nick, cred, u->user_agent);
}

static void log_user_login_error(struct hub_user* u, enum status_message msg)
{
	const char* addr = user_get_address(u);
	const char* message = hub_get_status_message_log(u->hub, msg);
	LOG_USER("LoginError  %s/%s %s \"%s\" (%s) \"%s\"", sid_to_string(u->id.sid), u->id.cid, addr, u->id.nick, message, u->user_agent);
}

static void log_user_update_error(struct hub_user* u, enum status_message msg)
{
	const char* addr = user_get_address(u);
	const char* message = hub_get_status_message_log(u->hub, msg);
	LOG_USER("UpdateError %s/%s %s \"%s\" (%s) \"%s\"", sid_to_string(u->id.sid), u->id.cid, addr, u->id.nick, message, u->user_agent);
}

static void log_user_logout(struct hub_user* u, const char* message)
{
	const char* addr = user_get_address(u);
	LOG_USER("Logout      %s/%s %s \"%s\" (%s)", sid_to_string(u->id.sid), u->id.cid, addr, u->id.nick, message);
}

static void log_user_nick_change(struct hub_user* u, const char* nick)
{
	const char* addr = user_get_address(u);
	LOG_USER("NickChange  %s/%s %s \"%s\" -> \"%s\"", sid_to_string(u->id.sid), u->id.cid, addr, u->id.nick, nick);
}
#endif /* !PLUGIN_SUPPORT */

/* Send MOTD, do logging etc */
void on_login_success(struct hub_info* hub, struct hub_user* u)
{
	/* Send user list of all existing users */
	if (!uman_send_user_list(hub, u))
		return;

	/* Mark as being in the normal state, and add user to the user list */
	user_set_state(u, state_normal);
	uman_add(hub, u);

#ifdef PLUGIN_SUPPORT
	plugin_log_user_login_success(hub, u);
#else
	/* Print log message */
	log_user_login(u);
#endif

	/* Announce new user to all connected users */
	if (user_is_logged_in(u))
		route_info_message(hub, u);
	
	/* Send message of the day (if any) */
	if (user_is_logged_in(u)) /* Previous send() can fail! */
		hub_send_motd(hub, u);

	/* Send message of the day (if any) */
	if (user_is_logged_in(u)) /* Previous send() can fail! */
		hub_send_rules(hub, u);

	/* reset timeout */
	net_con_clear_timeout(u->connection);
}

void on_login_failure(struct hub_info* hub, struct hub_user* u, enum status_message msg)
{
#ifdef PLUGIN_SUPPORT
	plugin_log_user_login_error(hub, u, hub_get_status_message_log(hub, msg));
#else
	log_user_login_error(u, msg);
#endif
	hub_send_status(hub, u, msg, status_level_fatal);
	hub_disconnect_user(hub, u, quit_logon_error);
}

void on_update_failure(struct hub_info* hub, struct hub_user* u, enum status_message msg)
{
#ifdef PLUGIN_SUPPORT
	plugin_log_user_update_error(hub, u, hub_get_status_message_log(hub, msg));
#else
	log_user_update_error(u, msg);
#endif
	hub_send_status(hub, u, msg, status_level_fatal);
	hub_disconnect_user(hub, u, quit_update_error);
}

void on_nick_change(struct hub_info* hub, struct hub_user* u, const char* nick)
{
	if (user_is_logged_in(u))
	{
#ifdef PLUGIN_SUPPORT
		plugin_log_user_nick_change(hub, u, nick);
#else
		log_user_nick_change(u, nick);
#endif
	}
}

void on_logout_user(struct hub_info* hub, struct hub_user* user)
{
	const char* reason = user_get_quit_reason_string(user->quit_reason);

#ifdef PLUGIN_SUPPORT
	plugin_log_user_logout(hub, user, reason);
#else
	log_user_logout(user, reason);
#endif

	hub_logout_log(hub, user);
}

