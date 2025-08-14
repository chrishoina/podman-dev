Rem  Copyright (c) Oracle Corporation 2018. All Rights Reserved.
Rem
Rem    NAME
Rem      create_projects.sql
Rem
Rem    DESCRIPTION
Rem      This script creates PROJECTS (Projects) sample schema
Rem
Rem    NOTES
Rem      Assumes the SYS user is connected.
Rem
Rem    MODIFIED   (MM/DD/YYYY)
Rem    sbkenned    10/11/2018 - Created


SET ECHO OFF
SET VERIFY OFF
SET HEADING OFF
SET FEEDBACK OFF

SET DEFINE '^'

DEFINE pass='^1'
DEFINE tbs='^2'
DEFINE overwrite_schema='^3'

-- Exit setup script on any error
WHENEVER SQLERROR EXIT SQL.SQLCODE

rem =======================================================
rem Accept and verify schema password
rem =======================================================

-- ACCEPT pass PROMPT 'Enter a password for the user PROJECTS: ' HIDE

BEGIN
   IF '^pass' IS NULL THEN
      RAISE_APPLICATION_ERROR(-20999, 'Error: the PROJECTS password is mandatory! Please specify a password!');
   END IF;
END;
/

rem =======================================================
rem Accept and verify tablespace name
rem =======================================================
COLUMN property_value NEW_VALUE var_default_tablespace NOPRINT
VARIABLE var_default_tablespace VARCHAR2(255)
SELECT NVL( '^tbs', property_value ) as property_value FROM database_properties WHERE property_name = 'DEFAULT_PERMANENT_TABLESPACE';
DEFINE tbs='^var_default_tablespace'

rem =======================================================
rem cleanup old PROJECTS schema, if found and requested
rem =======================================================

-- ACCEPT overwrite_schema PROMPT 'Do you want to overwrite the schema, if it already exists? [YES|no]: ' DEFAULT 'YES'

SET SERVEROUTPUT ON;
DECLARE
   v_user_exists   all_users.username%TYPE;
BEGIN
   SELECT MAX(username) INTO v_user_exists
      FROM all_users WHERE username = 'PROJECTS';
   -- Schema already exists
   IF v_user_exists IS NOT NULL THEN
      -- Overwrite schema if the user chose to do so
      IF UPPER('^overwrite_schema') = 'YES' THEN
         EXECUTE IMMEDIATE 'DROP USER PROJECTS CASCADE';
         DBMS_OUTPUT.PUT_LINE('Old PROJECTS schema has been dropped.');
      -- or raise error if the user doesn't want to overwrite it
      ELSE
         RAISE_APPLICATION_ERROR(-20997, 'Abort: the schema already exists and the user chose not to overwrite it.');
      END IF;
   END IF;
END;
/
SET SERVEROUTPUT OFF;

create user PROJECTS identified by "^pass"
       default tablespace ^tbs quota unlimited on ^tbs
       account lock password expire;

GRANT CREATE TABLE,
   CREATE TRIGGER,
   CREATE VIEW
TO PROJECTS;

alter session set current_schema = PROJECTS;
ALTER SESSION SET NLS_LANGUAGE=American;
ALTER SESSION SET NLS_TERRITORY=America;

create table project_status (
   id                  number        not null   
                       constraint project_users_pk   
                       primary key,   
   code                varchar2(15) not null,   
   description         varchar2(255) not null,   
   display_order       number not null,   
   created             timestamp with local time zone  not null,   
   created_by          varchar2(255)                   not null,   
   updated             timestamp with local time zone  not null,   
   updated_by          varchar2(255)                   not null );

alter table project_status add constraint project_status_uk unique (code);

create or replace trigger project_status_biu   
before insert or update on project_status   
    for each row   
begin   
    if :new.id is null then   
        :new.id := to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');   
    end if;   
   
    if inserting then   
        :new.created    := localtimestamp;   
        :new.created_by := nvl(sys_context('APEX$SESSION','APP_USER'),user);   
    end if;   
    :new.code       := upper(:new.code);   
    :new.updated    := localtimestamp;   
    :new.updated_by := nvl(sys_context('APEX$SESSION','APP_USER'),user);   
end;
/


create table projects (   
   id                   number        not null   
                        constraint projects_pk    
                        primary key,   
   status_id            number,   
   name                 varchar2(255) not null,   
   description          varchar2(4000),   
   project_lead         varchar2(255),   
   budget               number,   
   completed_date       date,   
   created              timestamp with local time zone  not null,   
   created_by           varchar2(255)                   not null,   
   updated              timestamp with local time zone  not null,   
   updated_by           varchar2(255)                   not null );

alter table projects add constraint projects_uk unique (name);
alter table projects add constraint project_status_fk   
  foreign key (status_id) references project_status (id)   
  on delete set null;
create index projects_status_idx on projects (status_id);

create or replace trigger projects_biu   
    before insert or update on projects   
    for each row   
begin   
    if :new.id is null then   
        :new.id := to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');   
    end if;   
   
    if inserting then   
        :new.created    := localtimestamp;   
        :new.created_by := nvl(sys_context('APEX$SESSION','APP_USER'),user);   
    end if;   
    :new.updated    := localtimestamp;   
    :new.updated_by := nvl(sys_context('APEX$SESSION','APP_USER'),user);   
end;
/


create table project_milestones (   
   id                   number        not null   
                        constraint project_milestones_pk   
                        primary key,   
   project_id           number not null,   
   name                 varchar2(255) not null,   
   description          varchar2(4000),   
   due_date             date not null,   
   created              timestamp with local time zone  not null,   
   created_by           varchar2(255)                   not null,   
   updated              timestamp with local time zone  not null,   
   updated_by           varchar2(255)                   not null );

alter table project_milestones add constraint project_mstone_proj_fk   
  foreign key (project_id) references projects (id)   
  on delete cascade;
create index project_mstone_proj_idx on project_milestones (project_id);

create or replace trigger project_milestones_biu   
    before insert or update on project_milestones   
    for each row   
begin   
    if :new.id is null then   
        :new.id := to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');   
    end if;   
   
    if inserting then   
        :new.created    := localtimestamp;   
        :new.created_by := nvl(sys_context('APEX$SESSION','APP_USER'),user);   
    end if;   
    :new.updated    := localtimestamp;   
    :new.updated_by := nvl(sys_context('APEX$SESSION','APP_USER'),user);   
end;
/


create table project_tasks (   
   id                   number        not null   
                        constraint project_tasks_pk    
                        primary key,   
   project_id           number not null,   
   milestone_id         number,   
   name                 varchar2(255) not null,   
   description          varchar2(4000),   
   assignee             varchar2(255),   
   start_date           date not null,   
   end_date             date not null,   
   cost                 number,   
   is_complete_yn       varchar2(1),   
   created                 timestamp with local time zone  not null,   
   created_by              varchar2(255)                   not null,   
   updated                 timestamp with local time zone  not null,   
   updated_by              varchar2(255)                   not null );

alter table project_tasks add constraint project_tasks_uk unique (project_id, name);
alter table project_tasks add constraint project_task_proj_fk   
  foreign key (project_id) references projects (id)    
  on delete cascade;
create index project_task_proj_idx on project_tasks (project_id);
alter table project_tasks add constraint project_task_mstone_fk   
  foreign key (milestone_id) references project_milestones (id)    
  on delete set null;
create index project_task_mstone_idx on project_tasks (milestone_id);

create or replace trigger project_tasks_biu   
    before insert or update on project_tasks   
    for each row   
begin   
    if :new.id is null then   
        :new.id := to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');   
    end if;   
   
    if inserting then   
        :new.created    := localtimestamp;   
        :new.created_by := nvl(sys_context('APEX$SESSION','APP_USER'),user);   
    end if;   
    :new.updated    := localtimestamp;   
    :new.updated_by := nvl(sys_context('APEX$SESSION','APP_USER'),user);   
end;
/


create table project_task_todos (   
   id                 number        not null   
                      constraint project_task_todos_pk    
                      primary key,   
   project_id         number not null,   
   task_id            number not null,   
   name               varchar2(255) not null,   
   description        varchar2(4000),   
   assignee           varchar2(255),   
   is_complete_yn     varchar2(1),   
   created            timestamp with local time zone  not null,   
   created_by         varchar2(255)                   not null,   
   updated            timestamp with local time zone  not null,   
   updated_by         varchar2(255)                   not null );

alter table project_task_todos add constraint proj_task_todo_proj_fk   
  foreign key (project_id) references projects (id)    
  on delete cascade;
create index project_tsk_todo_pr_idx  on project_task_todos (project_id);
alter table project_task_todos add constraint project_tsk_todo_tsk_fk   
  foreign key (task_id) references project_tasks (id)   
  on delete cascade;
create index project_tsk_todo_tk_idx on project_task_todos (task_id);

create or replace trigger project_task_todos_biu   
    before insert or update on project_task_todos   
    for each row   
begin   
    if :new.id is null then   
        :new.id := to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');   
    end if;   
   
    if inserting then   
        :new.created    := localtimestamp;   
        :new.created_by := nvl(sys_context('APEX$SESSION','APP_USER'),user);   
    end if;   
    :new.updated    := localtimestamp;   
    :new.updated_by := nvl(sys_context('APEX$SESSION','APP_USER'),user);   
end;
/


create table project_task_links (   
   id                 number        not null   
                      constraint project_task_links_pk    
                      primary key,   
   project_id         number not null,   
   task_id            number not null,   
   link_type          varchar2(20) not null,   
   url                varchar2(255),   
   application_id     number,   
   application_page   number,   
   description        varchar2(4000),   
   created            timestamp with local time zone  not null,   
   created_by         varchar2(255)                   not null,   
   updated            timestamp with local time zone  not null,   
   updated_by         varchar2(255)                   not null );

alter table project_task_links add constraint project_tsk_link_prj_fk   
  foreign key (project_id) references projects (id)    
  on delete cascade;
create index project_tsk_link_pr_idx  on project_task_links (project_id);
alter table project_task_links add constraint project_tsk_link_tsk_fk   
  foreign key (task_id) references project_tasks (id)    
  on delete cascade;
create index project_tsk_link_tk_idx on project_task_links (task_id);
alter table project_task_links add constraint project_tsk_link_lty_ch check ( link_type in ('URL','Application'));

create or replace trigger project_task_links_biu   
    before insert or update on project_task_links   
    for each row   
begin   
    if :new.id is null then   
        :new.id := to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');   
    end if;   
   
    if inserting then   
        :new.created    := localtimestamp;   
        :new.created_by := nvl(sys_context('APEX$SESSION','APP_USER'),user);   
    end if;   
    :new.updated    := localtimestamp;   
    :new.updated_by := nvl(sys_context('APEX$SESSION','APP_USER'),user);   
end;
/


create table project_comments (   
   id                   number        not null   
                        constraint project_comments_pk    
                        primary key,   
   project_id           number not null,   
   comment_text         varchar2(4000) not null,   
   created              timestamp with local time zone  not null,   
   created_by           varchar2(255)                   not null,   
   updated              timestamp with local time zone  not null,   
   updated_by           varchar2(255)                   not null );
alter table project_comments add constraint project_comment_proj_fk   
  foreign key (project_id) references projects (id)    
  on delete cascade;
create index project_comment_prj_idx on project_comments (project_id);

create or replace trigger project_comments_biu   
    before insert or update on project_comments   
    for each row   
begin   
    if :new.id is null then   
        :new.id := to_number(sys_guid(), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX');   
    end if;   
   
    if inserting then   
        :new.created    := localtimestamp;   
        :new.created_by := nvl(sys_context('APEX$SESSION','APP_USER'),user);   
    end if;   
    :new.updated    := localtimestamp;   
    :new.updated_by := nvl(sys_context('APEX$SESSION','APP_USER'),user);   
end;
/


create view projects_completed_v as   
select p.id,
       p.name,
       p.project_lead,
       p.completed_date,
       p.budget,
       (select sum(t.cost)   
        from project_tasks t   
        where t.project_id = p.id   
       ) cost,
       (  (select count(*)   
           from project_milestones m,
                project_tasks t   
           where t.project_id = p.id   
           and   t.milestone_id = m.id   
           and   nvl(t.is_complete_yn,'N') = 'Y' 
           and   t.end_date <= m.due_date   
          )   
        + (select count(*)   
           from project_tasks t   
           where t.project_id = p.id   
           and   t.milestone_id is null   
           and   nvl(t.is_complete_yn,'N') = 'Y'
          )   
       ) tasks_on_time,
       (select count(*)   
        from project_milestones m,
             project_tasks t   
        where t.project_id = p.id   
        and   t.milestone_id = m.id   
        and   nvl(t.is_complete_yn,'N') = 'Y' 
        and   t.end_date > m.due_date   
       ) tasks_late,
       (select count(*)   
        from project_tasks t   
        where t.project_id = p.id   
        and   nvl(t.is_complete_yn,'N') = 'N'
       ) tasks_incomplete,
       (select count(*)   
        from project_milestones m   
        where m.project_id = p.id   
        and   not exists (select t.id   
                          from project_tasks t   
                          where t.milestone_id = m.id   
                          and   nvl(t.is_complete_yn,'N') = 'Y'   
                          and   t.end_date > m.due_date   
                         )   
       ) milestones_on_time,
       (select count(*)   
        from project_milestones m   
        where m.project_id = p.id   
        and   exists (select t.id   
                      from project_tasks t   
                      where t.milestone_id = m.id   
                      and   nvl(t.is_complete_yn,'N') = 'Y' 
                      and   t.end_date > m.due_date   
                     )   
       ) milestones_late,
       (select count(*)   
        from project_milestones m   
        where m.project_id = p.id   
        and   exists (select t.id   
                      from project_tasks t   
                      where t.milestone_id = m.id   
                      and   nvl(t.is_complete_yn,'N') = 'N' 
                     )   
       ) milestones_incomplete   
from projects p   
where p.status_id = 3;

insert into project_status (id, code, description, display_order) 
 values (1, 'ASSIGNED', 'Assigned', 1); 
insert into project_status (id, code, description, display_order) 
 values (2, 'IN-PROGRESS', 'In-Progress', 2); 
insert into project_status (id, code, description, display_order) 
 values (3, 'COMPLETED', 'Completed', 3); 
commit;

declare
        l_add_days          number;
        l_project_id        number;
        l_milestone_id      number;
        l_task_id           number; 
        l_comment_id        number;
begin
        l_add_days := sysdate - to_date('20170101','YYYYMMDD'); 
        -------------------------- 
        --<< Insert Project 1 >>-- 
        -------------------------- 
        insert into projects 
          (  name 
           , description 
           , project_lead 
           , budget
           , completed_date 
           , status_id 
          ) 
          values 
          (  'Configure Web Development Tool Environment' 
           , 'Determine the hardware and software required to develop with Web development tool.' 
           , 'Lucille Beatie'
           , 5000
           , to_date('20161005', 'YYYYMMDD') + l_add_days 
           , 3 
          ) 
          returning id into l_project_id; 
    
        -- Insert Tasks for Project 1  
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date
           , cost 
          ) 
        values 
          (  l_project_id 
           , 'Tameka Hall' 
           , 'Identify Server Requirements' 
           , 'Determine which databases will be used to install Web development tool for Development, QA, and Production.  
              Also specify which Web Listeners will be used for the three environments.' 
           , null 
           , 'Y' 
           , to_date('20161001', 'YYYYMMDD') + l_add_days 
           , to_date('20161002', 'YYYYMMDD') + l_add_days 
           , 2000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Mei Yu' 
           , 'Install Web development tool' 
           , 'Install the latest version of Web development tool from the vendor into the databases for Development, QA, and Production. 
              Note: For QA and Production, Web development tool should be configured as "run time" only.' 
           , null 
           , 'Y' 
           , to_date('20161003', 'YYYYMMDD') + l_add_days 
           , to_date('20161003', 'YYYYMMDD') + l_add_days 
           , 1000
          )
          returning id into l_task_id; 
    
        insert into project_task_todos
          (  project_id
           , task_id
           , assignee
           , name
           , description
           , is_complete_yn
          )
        values
          (  l_project_id
           , l_task_id
           , 'Mei Yu'
           , 'Download tool from vendor'
           , 'Download the latest available version of the Web development tool from the vendor site.'
           , 'Y'
          );
    
        insert into project_task_links
          (  project_id
           , task_id
           , link_type
           , url
           , application_id
           , application_page
           , description
          )
        values
          (  l_project_id
           , l_task_id
           , 'URL'
           , 'http://Web-tool.download.com'
           , null
           , null
           , 'Ficticous download page for Web development tool' 
          );
    
        insert into project_task_links
          (  project_id
           , task_id
           , link_type
           , url
           , application_id
           , application_page
           , description
          )
        values
          (  l_project_id
           , l_task_id
           , 'URL'
           , 'http://Web-tool.install.com'
           , null
           , null
           , 'Ficticous installation guide for Web development tool' 
          );
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date
           , cost 
          ) 
        values 
          (  l_project_id 
           , 'Harold Youngblood' 
           , 'Configure Web Listeners' 
           , 'Configure the three Web Listeners for Web development tool to support the Dev, QA, and Prod environments.' 
           , null 
           , 'Y' 
           , to_date('20161003', 'YYYYMMDD') + l_add_days 
           , to_date('20161003', 'YYYYMMDD') + l_add_days 
           , 500
          )
          returning id into l_task_id; 
    
        insert into project_task_todos
          (  project_id
           , task_id
           , assignee
           , name
           , description
           , is_complete_yn
          )
        values
          (  l_project_id
           , l_task_id
           , 'Harold Youngblood'
           , 'Download Web Listener from vendor'
           , 'Download the latest available version of the Web Listener from the vendor site.'
           , 'Y'
          );
    
        insert into project_task_links
          (  project_id
           , task_id
           , link_type
           , url
           , application_id
           , application_page
           , description
          )
        values
          (  l_project_id
           , l_task_id
           , 'URL'
           , 'http://Web-Listener.download.com'
           , null
           , null
           , 'Ficticous download page for Web Listener' 
          );
    
        insert into project_task_links
          (  project_id
           , task_id
           , link_type
           , url
           , application_id
           , application_page
           , description
          )
        values
          (  l_project_id
           , l_task_id
           , 'URL'
           , 'http://Web-Listener.install.com'
           , null
           , null
           , 'Ficticous installation guide for Web Listener' 
          );
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Bernard Jackman' 
           , 'Configure Web development tool Instance Administration Settings' 
           , 'Set the appropriate security and configuration settings for the development instance using specified tools. 
              Also set instance settings for QA and Production using the available APIs.' 
           , null 
           , 'Y' 
           , to_date('20161004', 'YYYYMMDD') + l_add_days 
           , to_date('20161004', 'YYYYMMDD') + l_add_days 
           , 500
          )
          returning id into l_task_id; 
    
        insert into project_task_links
          (  project_id
           , task_id
           , link_type
           , url
           , application_id
           , application_page
           , description
          )
        values
          (  l_project_id
           , l_task_id
           , 'URL'
           , 'https://Web-tool.admin.com'
           , null
           , null
           , 'Ficticous administration guide for Web development tool' 
          );
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Mei Yu' 
           , 'Define Workspaces' 
           , 'Define workspaces needed for different application development teams. 
              It is important that access be granted to the necessary schemas and/or new schemas created as appropriate. 
              Then export these workspaces and import them into QA and Production environments.' 
           , null 
           , 'Y' 
           , to_date('20161005', 'YYYYMMDD') + l_add_days 
           , to_date('20161005', 'YYYYMMDD') + l_add_days 
           , 500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Harold Youngblood'
           , 'Assign Workspace Administrators' 
           , 'In development assign a minimum of two Workspace administators to each workspace. 
              These administrators will then be responsible for maintaining developer access within their own workspaces.' 
           , null 
           , 'N' 
           , to_date('20161005', 'YYYYMMDD') + l_add_days 
           , to_date('20161005', 'YYYYMMDD') + l_add_days 
           , 250
          ); 
    
        -- Insert Project Comments for Project 1 
        insert into project_comments 
          (  project_id 
           , comment_text 
          ) 
        values 
          (  l_project_id 
           , 'We have decided to use the Web Listener included with the database for Dev Only and a separate Web Listener for QA and Prod.' 
          )
          returning id into l_comment_id; 
        update project_comments 
          set created = to_date('20161002', 'YYYYMMDD') + l_add_days 
          where id = l_comment_id; 
    
        insert into project_comments 
          (  project_id 
           , comment_text 
          ) 
        values 
          (  l_project_id 
           , 'Installed latest version of Web development tool.' 
          )
          returning id into l_comment_id; 
        update project_comments 
          set created = to_date('20161004', 'YYYYMMDD') + l_add_days 
          ,   created_by = 'MEIYU' 
          where id = l_comment_id; 
    
        insert into project_comments 
          (  project_id 
           , comment_text 
          ) 
        values 
          (  l_project_id 
           , 'Installed latest version of Web Listener in QA and Prod environments' 
          )
          returning id into l_comment_id; 
        update project_comments 
          set created = to_date('20161004', 'YYYYMMDD') + l_add_days 
          ,   created_by = 'HARRY' 
          where id = l_comment_id; 
        commit;
end;
/

declare
        l_add_days          number;
        l_project_id        number;
        l_milestone_id      number;
        l_task_id           number; 
        l_comment_id        number;
begin
        -------------------------- 
        --<< Insert Project 2 >>-- 
        -------------------------- 
        l_add_days := sysdate - to_date('20170101','YYYYMMDD'); 
        insert into projects 
          (  name 
           , description 
           , project_lead 
           , budget
           , completed_date 
           , status_id 
          ) 
          values 
          (  'Train Developers on Web development tool' 
           , 'Ensure all developers who will be developing with the new tool get the appropriate training.' 
           , 'Lucille Beatie'
           , 20000
           , to_date('20161016', 'YYYYMMDD') + l_add_days 
           , 3 
          )
          returning id into l_project_id; 
    
        -- Insert Milestone 1 for Project 2 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Train the Trainers' 
           , 'Rather than all developers being trained centrally, a select group will be trained. 
              These people will then be responsible for training other developers in their group.' 
           , to_date('20161011', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 2 / Milestone 1 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith' 
           , 'Prepare Course Outline' 
           , 'Creation of the training syllabus' 
           , l_milestone_id 
           , 'Y' 
           , to_date('20161001', 'YYYYMMDD') + l_add_days 
           , to_date('20161005', 'YYYYMMDD') + l_add_days 
           , 5000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Write Training Guide' 
           , 'Produce the powerpoint deck (with notes) for the training instructor.' 
           , l_milestone_id
           , 'N' 
           , to_date('20161006', 'YYYYMMDD') + l_add_days 
           , to_date('20161008', 'YYYYMMDD') + l_add_days 
           , 3000
          )
          returning id into l_task_id; 
    
        insert into project_task_todos
          (  project_id
           , task_id
           , assignee
           , name
           , description
           , is_complete_yn
          )
        values
          (  l_project_id
           , l_task_id
           , 'Madison Smith'
           , 'Review the online examples hosted by the vendor'
           , 'Run through the numerous examples available from the vendor to get course content.'
           , 'Y'
          );
    
        insert into project_task_links
          (  project_id
           , task_id
           , link_type
           , url
           , application_id
           , application_page
           , description
          )
        values
          (  l_project_id
           , l_task_id
           , 'URL'
           , 'https://Web-tool.examples.com'
           , null
           , null
           , 'Ficticous examples page for Web development tool' 
          );
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Miyazaki Yokohama'
           , 'Develop Training Exercises' 
           , 'Create scripts for sample data and problem statements with solutions.' 
           , l_milestone_id 
           , 'Y' 
           , to_date('20161002', 'YYYYMMDD') + l_add_days 
           , to_date('20161008', 'YYYYMMDD') + l_add_days 
           , 5000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date
           , cost 
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Conduct Train-the-Trainer session' 
           , 'Give the training material to the selected developers.' 
           , l_milestone_id 
           , 'Y' 
           , to_date('20161009', 'YYYYMMDD') + l_add_days 
           , to_date('20161011', 'YYYYMMDD') + l_add_days 
           , 2500
          ); 
    
        -- Insert Milestone 2 for Project 2 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'All Developers Trained' 
           , 'Train the Trainers will have successfully trained the remaining development team members.' 
           , to_date('20161015', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 2 / Milestone 2 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Tyson King' 
           , 'Train Developers I' 
           , 'Give the training to developers within your group.' 
           , l_milestone_id 
           , 'Y' 
           , to_date('20161012', 'YYYYMMDD') + l_add_days 
           , to_date('20161014', 'YYYYMMDD') + l_add_days 
           , 3000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Daniel James Lee'
           , 'Train Developers II' 
           , 'Give the training to developers within your group.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161014', 'YYYYMMDD') + l_add_days 
           , to_date('20161016', 'YYYYMMDD') + l_add_days 
           , 3000
          ); 
    
        -- Insert Project Comments for Project 2 
        insert into project_comments 
          (  project_id 
           , comment_text 
          ) 
        values 
          (  l_project_id 
           , 'The exercises had some errors that need correcting ASAP.' 
          )
          returning id into l_comment_id; 
        update project_comments 
          set created = to_date('20161011', 'YYYYMMDD') + l_add_days 
          where id = l_comment_id; 
    
        insert into project_comments 
          (  project_id 
           , comment_text 
          ) 
        values 
          (  l_project_id 
           , 'Thanks for the feedback, Exercises corrected.' 
          )
          returning id into l_comment_id; 
        update project_comments 
          set created = to_date('20161012', 'YYYYMMDD') + l_add_days 
          ,   created_by = 'TKING' 
          where id = l_comment_id; 
        commit;

    end;
/
 
declare
        l_add_days          number;
        l_project_id        number;
        l_milestone_id      number;
        l_task_id           number; 
        l_comment_id        number;
begin
        -------------------------- 
        --<< Insert Project 3 >>-- 
        -------------------------- 
        l_add_days := sysdate - to_date('20170101','YYYYMMDD'); 
        insert into projects 
          (  name 
           , description 
           , project_lead
           , budget 
           , completed_date 
           , status_id 
          ) 
          values 
          (  'Migrate Legacy Applications' 
           , 'Move the data and redevelop the applications currently running on top of legacy servers' 
           , 'Miyazaki Yokohama'
           , 38000
           , null 
           , 2 
          )
          returning id into l_project_id; 
    
        -- Insert Milestone 1 for Project 3 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Move Data Structures' 
           , 'Move all of the tables and program logic across to the new database' 
           , to_date('20161220', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 3 / Milestone 1 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date
           , cost 
          ) 
        values 
          (  l_project_id 
           , 'Tameka Hall' 
           , 'Create New Tables' 
           , 'Create table scripts to replicate the legacy tables' 
           , l_milestone_id 
           , 'Y' 
           , to_date('20161214', 'YYYYMMDD') + l_add_days 
           , to_date('20161214', 'YYYYMMDD') + l_add_days
           , 500 
          )
          returning id into l_task_id; 
    
        insert into project_task_todos
          (  project_id
           , task_id
           , assignee
           , name
           , description
           , is_complete_yn
          )
        values
          (  l_project_id
           , l_task_id
           , 'Tameka Hall'
           , 'Reverse engineer the legacy tables into the data modeling tool'
           , 'Connect the data modeling tool to the legacy dev instance and suck in all of the required DB objects.'
           , 'Y'
          );
    
        insert into project_task_links
          (  project_id
           , task_id
           , link_type
           , url
           , application_id
           , application_page
           , description
          )
        values
          (  l_project_id
           , l_task_id
           , 'URL'
           , 'http://Web-data-modeler.info.com'
           , null
           , null
           , 'Ficticous information site for the data mdoeling tool' 
          );
    
        insert into project_task_todos
          (  project_id
           , task_id
           , assignee
           , name
           , description
           , is_complete_yn
          )
        values
          (  l_project_id
           , l_task_id
           , 'Tameka Hall'
           , 'Add proper integrity constraints to the entities'
           , 'Add foreign keys as needed to correctly integrate referential integrity.'
           , 'Y'
          );
    
        insert into project_task_todos
          (  project_id
           , task_id
           , assignee
           , name
           , description
           , is_complete_yn
          )
        values
          (  l_project_id
           , l_task_id
           , 'Tameka Hall'
           , 'Generate DDL Scripts for new tables'
           , 'Generate the DDL scripts from the data modeling tool to create the DB objects in the new database.'
           , 'Y'
          );
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           ,  'Nina Herschel'
           , 'Migrate data from Legacy Server' 
           , 'Develop scripts to populate the new database tables from the legacy database.' 
           , l_milestone_id 
           , 'Y' 
           , to_date('20161215', 'YYYYMMDD') + l_add_days 
           , to_date('20161218', 'YYYYMMDD') + l_add_days 
           , 3000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Tameka Hall'
           , 'Convert transaction logic' 
           , 'Convert the legacy database transactional objects across to the new database' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161215', 'YYYYMMDD') + l_add_days 
           , to_date('20161217', 'YYYYMMDD') + l_add_days 
           , 2500
          ); 
    
        -- Insert Milestone 2 for Project 3 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Redevelop HR Applications' 
           , 'Build applications to replace the HR functionality currently implemented in older technologies' 
           , to_date('20161228', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 3 / Milestone 2 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Eva Jelinek'
           , 'Redevelop Timesheet App' 
           , 'Develop desktop and mobile app for entering timesheets' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161217', 'YYYYMMDD') + l_add_days 
           , to_date('20161222', 'YYYYMMDD') + l_add_days 
           , 6000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Daniel Lee James'
           , 'Create Shift Schedule App' 
           , 'Create an app for defining when people are scheduled to work different shifts.' 
           , l_milestone_id 
           , 'Y' 
           , to_date('20161217', 'YYYYMMDD') + l_add_days 
           , to_date('20161225', 'YYYYMMDD') + l_add_days 
           , 7500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date
           , cost 
          ) 
        values 
          (  l_project_id 
           , 'Daniel Lee James'
           , 'Reengineer Employee App' 
           , 'Create an app for employee details and benefits.' 
           , l_milestone_id
           , 'N' 
           , to_date('20161226', 'YYYYMMDD') + l_add_days 
           , to_date('20161228', 'YYYYMMDD') + l_add_days 
           , 3000
          ); 
    
        -- Insert Milestone 3 for Project 3 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Redevelop Project Tracking Applications' 
           , 'Build applications to replace the project tracking functionality currently running on legacy servers' 
           , to_date('20170103', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 3 / Milestone 3 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Brock Shilling'
           , 'Customize Customer Tracker Packaged App' 
           , 'Install Customer Tracker and use flex fields to meet requirements.' 
           , l_milestone_id 
           , 'Y' 
           , to_date('20161228', 'YYYYMMDD') + l_add_days 
           , to_date('20161228', 'YYYYMMDD') + l_add_days 
           , 750
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Brock Shilling'
           , 'Migrate data into Customer Tracker tables' 
           , 'Move previous project tracking data into the Customer Tracker APEX$CUST_xxx tables.' 
           , l_milestone_id 
           , 'Y' 
           , to_date('20161229', 'YYYYMMDD') + l_add_days 
           , to_date('20161230', 'YYYYMMDD') + l_add_days 
           , 2000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Bernard Jackman'
           , 'Pilot new Customer Tracker application' 
           , 'Use Customer Tracker to ensure it meets requirements.' 
           , l_milestone_id
           , 'N' 
           , to_date('20161231', 'YYYYMMDD') + l_add_days 
           , to_date('20170109', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        -- Insert Project Comments for Project 3 
        insert into project_comments 
          (  project_id 
           , comment_text 
          ) 
        values 
          (  l_project_id 
           , 'Bernie - I have migrated all of the projects data across, so you can start your pilot now.' 
          )
          returning id into l_comment_id; 
        update project_comments 
          set created = to_date('201612310100', 'YYYYMMDDHH24MI') + l_add_days 
          ,   created_by = 'THEBROCK' 
          where id = l_comment_id; 
    
        insert into project_comments 
          (  project_id 
           , comment_text 
          ) 
        values 
          (  l_project_id 
           , 'I''m telling you now, this Customer Tracker thing had better be good' 
          )
          returning id into l_comment_id; 
        update project_comments 
          set created = to_date('201612310200', 'YYYYMMDDHH24MI') + l_add_days 
          ,   created_by = 'BERNIE' 
          where id = l_comment_id; 
    
        insert into project_comments 
          (  project_id 
           , comment_text 
          ) 
        values 
          (  l_project_id 
           , 'This guy Mike told me this app is brilliant.' 
          )
          returning id into l_comment_id; 
        update project_comments 
          set created = to_date('201612310300', 'YYYYMMDDHH24MI') + l_add_days 
          ,   created_by = 'THEBROCK' 
          where id = l_comment_id; 
    
        insert into project_comments 
          (  project_id 
           , comment_text 
          ) 
        values 
          (  l_project_id 
           , 'So far Customer Tracker is working out great - better than the old apps. Brocky, my boy, you are the man!' 
          )
          returning id into l_comment_id; 
        update project_comments 
          set created = to_date('201701010100', 'YYYYMMDDHH24MI') + l_add_days 
          ,   created_by = 'BERNIE' 
          where id = l_comment_id; 
    
        insert into project_comments 
          (  project_id 
           , comment_text 
          ) 
        values 
          (  l_project_id 
           , 'Bernie, I told you that you were going to be impressed.' 
          )
          returning id into l_comment_id; 
        update project_comments 
          set created = to_date('201701010200', 'YYYYMMDDHH24MI') + l_add_days 
          ,   created_by = 'THEBROCK' 
          where id = l_comment_id; 
    
        insert into project_comments 
          (  project_id 
           , comment_text 
          ) 
        values 
          (  l_project_id 
           , 'All of the old tables and transactional logic now migrated and ready for developers to use in the new database.' 
          )
          returning id into l_comment_id; 
        update project_comments 
          set created = to_date('20161217', 'YYYYMMDD') + l_add_days 
          ,   created_by = 'THALL' 
          where id = l_comment_id; 
        commit;
    end;
/
 
 
declare
        l_add_days          number;
        l_project_id        number;
        l_milestone_id      number;
        l_task_id           number; 
        l_comment_id        number;
begin
        -------------------------- 
        --<< Insert Project 4 >>-- 
        -------------------------- 
        l_add_days := sysdate - to_date('20170101','YYYYMMDD'); 
        insert into projects 
          (  name 
           , description 
           , project_lead 
           , budget
           , completed_date 
           , status_id 
          ) 
          values 
          (  'Develop Partner Portal POC' 
           , 'Develop a proof of concept that partners can use to work more collaboratively with us.' 
           , 'Bernard Jackman' 
           , 25000 
           , null
           , 2 
          )
          returning id into l_project_id; 
    
        -- Insert Milestone 1 for Project 4 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Define Requirements' 
           , 'Work with key stakeholders to define the scope of the project, and design screen flow and data requirements.' 
           , to_date('20170106', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 4 / Milestone 1 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Bernanrd Jackman'
           , 'Define scope of Partner Portal App.' 
           , 'Meet with internal and external SMEs and define the requirements' 
           , l_milestone_id
           , 'N' 
           , to_date('20161228', 'YYYYMMDD') + l_add_days 
           , to_date('20170104', 'YYYYMMDD') + l_add_days 
           , 4000
          )
          returning id into l_task_id; 
    
        insert into project_task_todos
          (  project_id
           , task_id
           , assignee
           , name
           , description
           , is_complete_yn
          )
        values
          (  l_project_id
           , l_task_id
           , 'Bernanrd Jackman'
           , 'Meet key Partners for input'
           , 'Determine the most important functionality for Partners.'
           , 'Y'
          );
    
        insert into project_task_todos
          (  project_id
           , task_id
           , assignee
           , name
           , description
           , is_complete_yn
          )
        values
          (  l_project_id
           , l_task_id
           , 'Bernard Jackman'
           , 'Meet internal Partner liason reps'
           , 'Determine the most important functionality for internal stakeholders.'
           , 'Y'
          );
    
        insert into project_task_todos
          (  project_id
           , task_id
           , assignee
           , name
           , description
           , is_complete_yn
          )
        values
          (  l_project_id
           , l_task_id
           , 'Bernard Jackman'
           , 'Develop inital screen designs'
           , 'Prototype new screens using Web development tool to get buy-in from SMEs.'
           , 'Y'
          );
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Daniel James Lee'
           , 'Define Partner App Data Structures' 
           , 'Design the data model for new and existing entities required to support the Partner Portal.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170104', 'YYYYMMDD') + l_add_days 
           , to_date('20170107', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Design User Experience' 
           , 'Define how partners will interact with the application.' 
           , l_milestone_id 
           , 'N' 
           , to_date('20170105', 'YYYYMMDD') + l_add_days 
           , to_date('20170106', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
    
        -- Insert Milestone 2 for Project 4 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Build Proof-of-Concept' 
           , 'Create the initial screens and populate with data so key stakeholders can review proposed solution.' 
           , to_date('20170113', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 4 / Milestone 2 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Nina Herschel'
           , 'Develop Admin Screens for Partner Portal' 
           , 'Develop the screens needed to maintain all of the base tables for the Partner Portal app.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170108', 'YYYYMMDD') + l_add_days 
           , to_date('20170110', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Harold Youngblood'
           , 'Populate Data Structures for Partner Portal' 
           , 'Upload sample data provided by key partner, and ensure existing tables accessible.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170108', 'YYYYMMDD') + l_add_days 
           , to_date('20170109', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Design first-cut of main Partner Portal app' 
           , 'Implement the major functional areas and ensure navigation between pages is working correctly.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170107', 'YYYYMMDD') + l_add_days 
           , to_date('20170111', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Bernard Jackman'
           , 'Present POC to Key Stakeholders' 
           , 'Walk key stakeholders through the proof of concept and obtain their feedback.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170112', 'YYYYMMDD') + l_add_days 
           , to_date('20170112', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
        commit;
    end;
/
 
 
declare
        l_add_days          number;
        l_project_id        number;
        l_milestone_id      number;
        l_task_id           number; 
        l_comment_id        number;
    begin
        -------------------------- 
        --<< Insert Project 5 >>-- 
        -------------------------- 
        l_add_days := sysdate - to_date('20170101','YYYYMMDD'); 
        insert into projects 
          (  name 
           , description 
           , project_lead 
           , budget
           , completed_date 
           , status_id 
          ) 
          values 
          (  'Develop Production Partner Portal' 
           , 'Develop the production app that partners can use to work more collaboratively with us.' 
           , 'Lucille Beatie'
           , 85000
           , null 
           , 1 
          )
          returning id into l_project_id; 
    
        -- Insert Milestone 1 for Project 5 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Define Production App Scope' 
           , 'Based on the results of the POC, define the requirements for the production app.' 
           , to_date('20170114', 'YYYYMMDD') + l_add_days 
         )
         returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 5 / Milestone 1 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Lucille Beatie'
           , 'Define production scope of Partner Portal App.' 
           , 'Define the scope and timelines for the development of the production app.' 
           , l_milestone_id 
           , 'N' 
           , to_date('20170113', 'YYYYMMDD') + l_add_days 
           , to_date('20170114', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Daniel Lee James'
           , 'Finalize Partner App Data Model' 
           , 'Refine the data model for new and existing entities required to support the Partner Portal.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170113', 'YYYYMMDD') + l_add_days 
           , to_date('20170114', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Finalize User Experience' 
           , 'Write developer standards on UX and development standards on how partners will interact with the application.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170113', 'YYYYMMDD') + l_add_days 
           , to_date('20170114', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
    
        -- Insert Milestone 2 for Project 5 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Build Phase 1 of Production Partner Portal App' 
           , 'Develop the modules defined in the first phase of the application.' 
           , to_date('20170121', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 5 / Milestone 2 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Refine Admin Screens for Partner Portal' 
           , 'Refine screens developed in the POC to be fully operational to maintain all of the base tables for the Partner Portal app.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170115', 'YYYYMMDD') + l_add_days 
           , to_date('20170118', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Mei Yu'
           , 'Populate Data Structures for Production Partner Portal' 
           , 'Upload actual data provided by key partner, and ensure existing tables accessible.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170115', 'YYYYMMDD') + l_add_days 
           , to_date('20170117', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Tyson King'
           , 'Design production screens for main Partner Portal app' 
           , 'Implement fully functional and complete screens to cover the major functional areas in Phase 1.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170117', 'YYYYMMDD') + l_add_days 
           , to_date('20170123', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        -- Insert Milestone 3 for Project 5 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Perform Beta testing with select Partners' 
           , 'Work with a few key partners to trial Phase 1 of the Partner Portal app.' 
           , to_date('20170129', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 5 / Milestone 3 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Miyazaki Yokohama'
           , 'Train Partners' 
           , 'Train selected partners in how to use the Partner Portal app.' 
           , l_milestone_id 
           , 'N' 
           , to_date('20170122', 'YYYYMMDD') + l_add_days 
           , to_date('20170122', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Eva Jelinek'
           , 'Monitor Partners' 
           , 'Monitor partners selected for the Beta and provide assistance as necessary.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170123', 'YYYYMMDD') + l_add_days 
           , to_date('20170128', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Lucille Beatie'
           , 'Review Beta Feedback' 
           , 'Analyse feedback from the partners who participated in the Beta program.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170129', 'YYYYMMDD') + l_add_days 
           , to_date('20170129', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        -- Insert Milestone 4 for Project 5 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Complete Phase 1 Development of Partner Portal app' 
           , 'Based on the results of the Beta program, enhance the application to make production ready.' 
           , to_date('20170225', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 5 / Milestone 4 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Mei Yu'
           , 'Improve existing feature functions' 
           , 'Enhance existing features based on responses from Beta partners.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170201', 'YYYYMMDD') + l_add_days 
           , to_date('20170220', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Tameka Hall'
           , 'Add required feature functions' 
           , 'Add missing features outlined in responses from Beta partners.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170201', 'YYYYMMDD') + l_add_days 
           , to_date('20170220', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Harold Youngblood'
           , 'Load full production data' 
           , 'Ensure all data required for production roll out are inserted and maintained.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170215', 'YYYYMMDD') + l_add_days 
           , to_date('20170220', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Daniel Lee James'
           , 'Test Production Partner Portal' 
           , 'Do full scale testing on the Partner Portal application.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170221', 'YYYYMMDD') + l_add_days 
           , to_date('20170225', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        -- Insert Milestone 5 for Project 5 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Roll out Phase 1 of Partner Portal app' 
           , 'Go-Live for the Partner Portal application to all partners.' 
           , to_date('20170301', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 5 / Milestone 5 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Tameka Hall'
           , 'Install Partner Portal app onto Production Server' 
           , 'Install the database objects and application(s) into the production environment.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170226', 'YYYYMMDD') + l_add_days 
           , to_date('20170226', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Harold Youngblood'
           , 'Configure production data load procedures' 
           , 'Install and test data load procedures from internal and external data sources into production environment.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170227', 'YYYYMMDD') + l_add_days 
           , to_date('20170228', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Lucille Beatie'
           , 'Provide user credentials for partners' 
           , 'Define user credentials for each partner to allow access to the Partner Portal app.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170228', 'YYYYMMDD') + l_add_days 
           , to_date('20170228', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Lucille Beatie'
           , 'Announce Partner Portal app to all partners' 
           , 'Email or call partners to inform them of the new application and instructions on how to get started.' 
           , l_milestone_id
           , 'N' 
           , to_date('20170301', 'YYYYMMDD') + l_add_days 
           , to_date('20170301', 'YYYYMMDD') + l_add_days 
           , 0
          ); 
        commit;
    end;
/
 
 
declare
        l_add_days          number;
        l_project_id        number;
        l_milestone_id      number;
        l_task_id           number; 
        l_comment_id        number;
begin
        -------------------------- 
        --<< Insert Project 6 >>-- 
        -------------------------- 
        l_add_days := sysdate - to_date('20170101','YYYYMMDD'); 
        insert into projects 
          (  name 
           , description 
           , project_lead 
           , budget
           , completed_date 
           , status_id 
          ) 
          values 
          (  'Develop New Reporting Apps' 
           , 'Develop apps to meet C Level reporting requirements.' 
           , 'Lucille Beatie' 
           , 15000 
           , to_date('20161030', 'YYYYMMDD') + l_add_days
           , 3
          )
          returning id into l_project_id; 
    
        -- Insert Milestone 1 for Project 6 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Define Reporting Requirements`' 
           , 'Work with key stakeholders to define the scope of the project, and design data requirements.' 
           , to_date('20161022', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 6 / Milestone 1 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Lucille Beatie'
           , 'Define scope of CEO Reporting' 
           , 'Meet with executives to define the high level requirements' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161018', 'YYYYMMDD') + l_add_days 
           , to_date('20161018', 'YYYYMMDD') + l_add_days 
           , 1000
          )
          returning id into l_task_id; 
    
        insert into project_task_todos
          (  project_id
           , task_id
           , assignee
           , name
           , description
           , is_complete_yn
          )
        values
          (  l_project_id
           , l_task_id
           , 'Lucille Beatie'
           , 'Contact executive assitants'
           , 'Get meetings scheduled for the key stakeholders.'
           , 'Y'
          );
    
        insert into project_task_todos
          (  project_id
           , task_id
           , assignee
           , name
           , description
           , is_complete_yn
          )
        values
          (  l_project_id
           , l_task_id
           , 'Lucille Beatie'
           , 'Prepare presentation for executives'
           , 'Prepare and practice delivering concise, high level positioning on app feasability.'
           , 'Y'
          );
    
        insert into project_task_todos
          (  project_id
           , task_id
           , assignee
           , name
           , description
           , is_complete_yn
          )
        values
          (  l_project_id
           , l_task_id
           , 'Mei Yu'
           , 'Develop inital report designs'
           , 'Mock up new dashboard screens using Web development tool to get buy-in from executives.'
           , 'Y'
          );
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Mei Yu'
           , 'Define data requirements' 
           , 'Specify the data sources required to support the reports.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161019', 'YYYYMMDD') + l_add_days 
           , to_date('20161021', 'YYYYMMDD') + l_add_days 
           , 3000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Design Dashboard presentation' 
           , 'Define how data will be displayed in the dashboard.' 
           , l_milestone_id 
           , 'Y' 
           , to_date('20161021', 'YYYYMMDD') + l_add_days 
           , to_date('20161022', 'YYYYMMDD') + l_add_days 
           , 1500
          ); 
    
    
        -- Insert Milestone 2 for Project 6 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Build First Cut of Executive Dashboard' 
           , 'Create the initial screens and populate with data so key executives can review the initial solution.' 
           , to_date('20161030', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 6 / Milestone 2 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Nina Herschel'
           , 'Develop Admin Screens for Executive Dashboard`' 
           , 'Develop the screens needed to maintain all of the base tables for the executive reporting app.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161023', 'YYYYMMDD') + l_add_days 
           , to_date('20161023', 'YYYYMMDD') + l_add_days 
           , 1000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Mei Yu'
           , 'Populate Data Structures for Executive Dashboard' 
           , 'Upload reporting data from external sources into local tables.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161023', 'YYYYMMDD') + l_add_days 
           , to_date('20161024', 'YYYYMMDD') + l_add_days 
           , 2000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Build first-cut of Executive Dashboard app' 
           , 'Implement the major functional areas and ensure navigation between pages is working correctly.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161025', 'YYYYMMDD') + l_add_days 
           , to_date('20161029', 'YYYYMMDD') + l_add_days 
           , 4000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Lucille Beatie'
           , 'Present First Cut to executives' 
           , 'Walk key stakeholders through the initial reports and obtain their feedback.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161030', 'YYYYMMDD') + l_add_days 
           , to_date('20161030', 'YYYYMMDD') + l_add_days 
           , 500
          ); 
        commit;
    end;
/
 
 
declare
        l_add_days          number;
        l_project_id        number;
        l_milestone_id      number;
        l_task_id           number; 
        l_comment_id        number;
begin
        -------------------------- 
        --<< Insert Project 7 >>-- 
        -------------------------- 
        l_add_days := sysdate - to_date('20170101','YYYYMMDD'); 
        insert into projects 
          (  name 
           , description 
           , project_lead 
           , budget
           , completed_date 
           , status_id 
          ) 
          values 
          (  'Develop IT Management Apps' 
           , 'Develop apps to allow IT to manage resources.' 
           , 'Bernard Jackman'
           , 45000
           , to_date('20161110', 'YYYYMMDD') + l_add_days 
           , 3 
          )
          returning id into l_project_id; 
    
        -- Insert Milestone 1 for Project 7
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Define IT Management App Scope' 
           , 'Define the different apps required to meet IT requirements.' 
           , to_date('20161025', 'YYYYMMDD') + l_add_days 
         )
         returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 7 / Milestone 1 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Bernard Jackman'
           , 'Define main IT requirements.' 
           , 'Define the scope and timelines for the development of the IT Management apps.' 
           , l_milestone_id 
           , 'Y' 
           , to_date('20161020', 'YYYYMMDD') + l_add_days 
           , to_date('20161021', 'YYYYMMDD') + l_add_days 
           , 2000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Tyson King'
           , 'Finalize IT Management Apps Data Model' 
           , 'Define the data model for new and existing entities required to support the IT Management apps.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161021', 'YYYYMMDD') + l_add_days 
           , to_date('20161024', 'YYYYMMDD') + l_add_days 
           , 5000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Finalize User Experience' 
           , 'Write developer standards on UX and development standards on how IT will interact with the applications.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161023', 'YYYYMMDD') + l_add_days 
           , to_date('20161024', 'YYYYMMDD') + l_add_days 
           , 2500
          ); 
    
    
        -- Insert Milestone 2 for Project 7
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Build Phase 1 of IT Management Apps' 
           , 'Develop the modules defined in the first phase of the applications.' 
           , to_date('20161030', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 7 / Milestone 2 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Brock Shilling'
           , 'Define Admin Screens for IT Management Apps' 
           , 'Define screens to maintain all of the base tables for the IT Management apps.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161023', 'YYYYMMDD') + l_add_days 
           , to_date('20161025', 'YYYYMMDD') + l_add_days 
           , 3000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Eva Jelinek'
           , 'Populate Data Structures for IT Management Apps' 
           , 'Upload actual data provided from other IT systems.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161024', 'YYYYMMDD') + l_add_days 
           , to_date('20161026', 'YYYYMMDD') + l_add_days 
           , 3000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Tyson King'
           , 'Design production screens for IT Management apps' 
           , 'Implement fully functional and complete screens to cover the major functional areas in Phase 1.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161025', 'YYYYMMDD') + l_add_days 
           , to_date('20161030', 'YYYYMMDD') + l_add_days 
           , 6000
          ); 
    
        -- Insert Milestone 3 for Project 7 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Perform Beta testing with IT staff' 
           , 'Work with a few key IT personnel to trial Phase 1 of the IT Management apps.' 
           , to_date('20161105', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 7 / Milestone 3 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Tyson King'
           , 'Train IT personnel' 
           , 'Train selected IT staff in how to use the apps.' 
           , l_milestone_id 
           , 'Y' 
           , to_date('20161101', 'YYYYMMDD') + l_add_days 
           , to_date('20161101', 'YYYYMMDD') + l_add_days 
           , 1000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Eva Jelinek'
           , 'Monitor IT Staff' 
           , 'Monitor IT staff selected for the Beta and provide assistance as necessary.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161102', 'YYYYMMDD') + l_add_days 
           , to_date('20161104', 'YYYYMMDD') + l_add_days 
           , 3000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Bernard Jackman'
           , 'Review Beta Feedback' 
           , 'Analyse feedback from the IT staff who participated in the Beta program.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161105', 'YYYYMMDD') + l_add_days 
           , to_date('20161105', 'YYYYMMDD') + l_add_days 
           , 1000
          ); 
    
        -- Insert Milestone 4 for Project 7 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Complete Phase 1 Development of IT Management apps' 
           , 'Based on the results of the Beta program, enhance the application to make production ready.' 
           , to_date('20161110', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 7 / Milestone 4 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Brock Shilling'
           , 'Improve existing feature functions' 
           , 'Enhance existing features based on responses from Beta staff.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161106', 'YYYYMMDD') + l_add_days 
           , to_date('20161110', 'YYYYMMDD') + l_add_days 
           , 7000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Eva Jelinek'
           , 'Add required feature functions' 
           , 'Add missing features outlined in responses from Beta staff.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161106', 'YYYYMMDD') + l_add_days 
           , to_date('20161110', 'YYYYMMDD') + l_add_days 
           , 5500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Harold Youngblood'
           , 'Load full production data' 
           , 'Ensure all data required for production roll out are inserted and maintained.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161108', 'YYYYMMDD') + l_add_days 
           , to_date('20161110', 'YYYYMMDD') + l_add_days 
           , 3000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Daniel Lee James'
           , 'Test IT Management Apps' 
           , 'Do full scale testing on the IT Management apps.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161111', 'YYYYMMDD') + l_add_days 
           , to_date('20161111', 'YYYYMMDD') + l_add_days 
           , 1000
          ); 
    
        -- Insert Milestone 5 for Project 7 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Roll out Phase 1 of IT Management apps' 
           , 'Go-Live for the IT Management apps for IT staff.' 
           , to_date('20161116', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 7 / Milestone 5 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Harold Youngblood'
           , 'Install IT Management apps onto Production Server' 
           , 'Install the database objects and application(s) into the production environment.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161112', 'YYYYMMDD') + l_add_days 
           , to_date('20161112', 'YYYYMMDD') + l_add_days 
           , 1000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Harold Youngblood'
           , 'Configure production data load procedures' 
           , 'Install and test data load procedures from internal and external data sources into production environment.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161113', 'YYYYMMDD') + l_add_days 
           , to_date('20161114', 'YYYYMMDD') + l_add_days 
           , 2000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Tyson King'
           , 'Provide user credentials for IT staff' 
           , 'Define user credentials for each IT staff member to allow access to the IT Management apps.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161114', 'YYYYMMDD') + l_add_days 
           , to_date('20161114', 'YYYYMMDD') + l_add_days 
           , 1000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Bernard Jackman'
           , 'Announce IT Management apps to all IT staff' 
           , 'Email or call IT staff to inform them of the new application and instructions on how to get started.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161115', 'YYYYMMDD') + l_add_days 
           , to_date('20161115', 'YYYYMMDD') + l_add_days 
           , 1000
          ); 
        commit;
    end;
/
 
 
declare
        l_add_days          number;
        l_project_id        number;
        l_milestone_id      number;
        l_task_id           number; 
        l_comment_id        number;
begin
        -------------------------- 
        --<< Insert Project 8 >>-- 
        -------------------------- 
        l_add_days := sysdate - to_date('20170101','YYYYMMDD'); 
        insert into projects 
          (  name 
           , description 
           , project_lead 
           , budget
           , completed_date 
           , status_id 
          ) 
          values 
          (  'Develop Customer Tracker Application' 
           , 'Develop an application to track customers from prospects through closed deals.' 
           , 'Lucille Beatie' 
           , 14000 
           , to_date('20161130', 'YYYYMMDD') + l_add_days
           , 3
          )
          returning id into l_project_id; 
    
        -- Insert Milestone 1 for Project 8 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Review Packaged App' 
           , 'Work with key stakeholders to prioritize improvements to the default Packaged App.' 
           , to_date('20161118', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 8 / Milestone 1 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Miyazaki Yokohama'
           , 'Install Customer Tracker Packaged App' 
           , 'Install the packaged app and turn on the appropriate options.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161116', 'YYYYMMDD') + l_add_days 
           , to_date('20161116', 'YYYYMMDD') + l_add_days 
           , 1000
          )
          returning id into l_task_id; 
    
        insert into project_task_todos
          (  project_id
           , task_id
           , assignee
           , name
           , description
           , is_complete_yn
          )
        values
          (  l_project_id
           , l_task_id
           , 'Miyazaki Yokohama'
           , 'Contact executive assitants'
           , 'Get meetings scheduled for the key stakeholders.'
           , 'Y'
          );
    
        insert into project_task_todos
          (  project_id
           , task_id
           , assignee
           , name
           , description
           , is_complete_yn
          )
        values
          (  l_project_id
           , l_task_id
           , 'Miyazaki Yokohama'
           , 'Prepare presentation for executives'
           , 'Determine the current functionality to present to key stakeholders.'
           , 'Y'
          );
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Mei Yu'
           , 'Define external customer data feeds' 
           , 'Specify the data sources for customer data.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161116', 'YYYYMMDD') + l_add_days 
           , to_date('20161117', 'YYYYMMDD') + l_add_days 
           , 3000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Design Customer Tracker Look and Feel' 
           , 'Define how data will be displayed on customers.' 
           , l_milestone_id 
           , 'Y' 
           , to_date('20161117', 'YYYYMMDD') + l_add_days 
           , to_date('20161118', 'YYYYMMDD') + l_add_days 
           , 1500
          ); 
    
    
        -- Insert Milestone 2 for Project 8 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Deliver First-Cut of Customer Tracker' 
           , 'Create the initial screens and populate with data so key executives can review the initial solution.' 
           , to_date('20161122', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 8 / Milestone 2 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Miyazaki Yokohama'
           , 'Define necessary flex-fields within the Customer Tracker app' 
           , 'Add the additional customer attributes required using the flex fields.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161119', 'YYYYMMDD') + l_add_days 
           , to_date('20161119', 'YYYYMMDD') + l_add_days 
           , 500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Mei Yu'
           , 'Populate Data Structures for Customer Tracker' 
           , 'Upload existing customer data from external sources into local tables.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161120', 'YYYYMMDD') + l_add_days 
           , to_date('20161121', 'YYYYMMDD') + l_add_days 
           , 2000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Customize the Customer Tracker app' 
           , 'Use built-in functionality and Theme Roller to tweak the application.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161121', 'YYYYMMDD') + l_add_days 
           , to_date('20161121', 'YYYYMMDD') + l_add_days 
           , 500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Lucille Beatie'
           , 'Present First Cut to executives' 
           , 'Walk key stakeholders through the initial app and obtain their feedback.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161123', 'YYYYMMDD') + l_add_days 
           , to_date('20161123', 'YYYYMMDD') + l_add_days 
           , 500
          ); 
    
        -- Insert Milestone 3 for Project 8 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Deliver Final Customer Tracker Application' 
           , 'Deliver the completed application to the business.' 
           , to_date('20161130', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 8 / Milestone 3 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Miyazaki Yokohama'
           , 'Define additional flex-fields within the Customer Tracker app' 
           , 'Add the extra customer attributes required using the flex fields.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161125', 'YYYYMMDD') + l_add_days 
           , to_date('20161125', 'YYYYMMDD') + l_add_days 
           , 500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Mei Yu'
           , 'Final upload of Data Structures for Customer Tracker' 
           , 'Reload customer data from external sources into local tables.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161126', 'YYYYMMDD') + l_add_days 
           , to_date('20161126', 'YYYYMMDD') + l_add_days 
           , 1500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Customize the Customer Tracker app based on First-Cut feedback' 
           , 'Use built-in functionality and Theme Roller to tweak the application.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161126', 'YYYYMMDD') + l_add_days 
           , to_date('20161126', 'YYYYMMDD') + l_add_days 
           , 500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Miyazaki Yokohama'
           , 'Train reps on use of Customer Tracker' 
           , 'Walk key users through the application.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161127', 'YYYYMMDD') + l_add_days 
           , to_date('20161127', 'YYYYMMDD') + l_add_days 
           , 500
          );
    end;
/
 

declare
        l_add_days          number;
        l_project_id        number;
        l_milestone_id      number;
        l_task_id           number; 
        l_comment_id        number;
begin
        -------------------------- 
        --<< Insert Project 9 >>-- 
        -------------------------- 
        l_add_days := sysdate - to_date('20170101','YYYYMMDD'); 
        insert into projects 
          (  name 
           , description 
           , project_lead 
           , budget
           , completed_date 
           , status_id 
          ) 
          values 
          (  'Implement Customer Satisfaction Application' 
           , 'Implement an application to track customer satisfaction and feedback.' 
           , 'Bernard Jackman'
           , 25000
           , to_date('20161130', 'YYYYMMDD') + l_add_days 
           , 3 
          )
          returning id into l_project_id; 
    
        -- Insert Tasks for Project 9 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Bernard Jackman'
           , 'Define main requirements for tracking customer satisfaction.' 
           , 'Define the scope and timelines for the development of the tracking app.' 
           , null 
           , 'Y' 
           , to_date('20161117', 'YYYYMMDD') + l_add_days 
           , to_date('20161118', 'YYYYMMDD') + l_add_days 
           , 2000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Tyson King'
           , 'Finalize Customer Satisfaction Tracker Data Model' 
           , 'Define the data model for new and existing entities required to support customer satisfaction tracking.' 
           , null
           , 'Y' 
           , to_date('20161119', 'YYYYMMDD') + l_add_days 
           , to_date('20161121', 'YYYYMMDD') + l_add_days 
           , 3000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Finalize User Experience' 
           , 'Write developer standards on UX and development standards on how the company will acquire and report on customer satisfaction.' 
           , null
           , 'Y' 
           , to_date('20161119', 'YYYYMMDD') + l_add_days 
           , to_date('20161120', 'YYYYMMDD') + l_add_days 
           , 3000
          ); 
    
         insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Brock Shilling'
           , 'Define Admin Screens for Customer Satisfaction App' 
           , 'Define screens to maintain all of the base tables for the Customer Satisfaction apps.' 
           , null
           , 'Y' 
           , to_date('20161121', 'YYYYMMDD') + l_add_days 
           , to_date('20161122', 'YYYYMMDD') + l_add_days 
           , 2750
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Eva Jelinek'
           , 'Populate Data Structures for Customer Satisfaction Apps' 
           , 'Upload actual data provided from other IT systems.' 
           , null
           , 'Y' 
           , to_date('20161122', 'YYYYMMDD') + l_add_days 
           , to_date('20161122', 'YYYYMMDD') + l_add_days 
           , 1000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Tyson King'
           , 'Design production screens for the customer to provide feedback' 
           , 'Implement fully functional and complete screens to allow customers to provide feedback.' 
           , null
           , 'Y' 
           , to_date('20161123', 'YYYYMMDD') + l_add_days 
           , to_date('20161125', 'YYYYMMDD') + l_add_days 
           , 3500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Eva Jelinek'
           , 'Design internal screens for collecting feedback and analyzing results' 
           , 'Develop data entry and reporting screens to manage Customer Satisfaction.' 
           , null
           , 'Y' 
           , to_date('20161123', 'YYYYMMDD') + l_add_days 
           , to_date('20161126', 'YYYYMMDD') + l_add_days 
           , 5000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Daniel Lee James'
           , 'Test Customer Satisfaction internal / external apps' 
           , 'Do full scale testing on both the customer facing and internal-only screens.' 
           , null
           , 'Y' 
           , to_date('20161127', 'YYYYMMDD') + l_add_days 
           , to_date('20161128', 'YYYYMMDD') + l_add_days 
           , 3000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Harold Youngblood'
           , 'Contact initial customers to educate them on providing feedback' 
           , 'Work off a call list to email or call the beta customers and monitor their responses.' 
           , null
           , 'Y' 
           , to_date('20161127', 'YYYYMMDD') + l_add_days 
           , to_date('20161201', 'YYYYMMDD') + l_add_days 
           , 5500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Bernard Jackman'
           , 'Announce CUstomer Satisfaction apps to all customers and staff' 
           , 'Email all current customers and staff to inform them of the new application and instructions on how to get started.' 
           , null
           , 'Y' 
           , to_date('20161130', 'YYYYMMDD') + l_add_days 
           , to_date('20161130', 'YYYYMMDD') + l_add_days 
           , 1000
          ); 
        commit;
    end;
/


declare
        l_add_days          number;
        l_project_id        number;
        l_milestone_id      number;
        l_task_id           number; 
        l_comment_id        number;
begin
        --------------------------- 
        --<< Insert Project 10 >>-- 
        --------------------------- 
        l_add_days := sysdate - to_date('20170101','YYYYMMDD'); 
        insert into projects 
          (  name 
           , description 
           , project_lead 
           , budget
           , completed_date 
           , status_id 
          ) 
          values 
          (  'Improve IT Management Apps' 
           , 'Enahnce apps to allow IT to manage resources.' 
           , 'Bernard Jackman'
           , 40000
           , to_date('20161228', 'YYYYMMDD') + l_add_days 
           , 3 
          )
          returning id into l_project_id; 
    
        -- Insert Milestone 1 for Project 10
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Define IT Management App Enhancement Scope' 
           , 'Define the updates required to improve the apps.' 
           , to_date('20161205', 'YYYYMMDD') + l_add_days 
         )
         returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 10 / Milestone 1 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Bernard Jackman'
           , 'Define main IT requirements.' 
           , 'Define the scope and timelines for the improvement to the IT Management apps.' 
           , l_milestone_id 
           , 'Y' 
           , to_date('20161201', 'YYYYMMDD') + l_add_days 
           , to_date('20161201', 'YYYYMMDD') + l_add_days 
           , 1000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Tyson King'
           , 'Revise IT Management Apps Data Model' 
           , 'Define the data model for new entities required to support the updated IT Management apps.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161202', 'YYYYMMDD') + l_add_days 
           , to_date('20161204', 'YYYYMMDD') + l_add_days 
           , 3000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Refine User Experience for IT Management Apps' 
           , 'Update developer standards on UX and development standards on how IT will interact with the applications.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161202', 'YYYYMMDD') + l_add_days 
           , to_date('20161203', 'YYYYMMDD') + l_add_days 
           , 2500
          ); 
    
    
        -- Insert Milestone 2 for Project 10
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Build Final Phase of IT Management Apps' 
           , 'Develop the modules defined in the final phase of the applications.' 
           , to_date('20161212', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 10 / Milestone 2 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Eva Jelinek'
           , 'Populate New Data Structures for IT Management Apps' 
           , 'Upload actual data provided from other IT systems.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161204', 'YYYYMMDD') + l_add_days 
           , to_date('20161206', 'YYYYMMDD') + l_add_days 
           , 3000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Tyson King'
           , 'Design production screens for revised IT Management apps' 
           , 'Implement fully functional and complete screens to cover the major functional areas.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161204', 'YYYYMMDD') + l_add_days 
           , to_date('20161210', 'YYYYMMDD') + l_add_days 
           , 6000
          ); 
    
        -- Insert Milestone 3 for Project 10 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Perform Beta testing with IT staff of revised IT Management Apps' 
           , 'Work with a few key IT personnel to trial the final IT Management apps.' 
           , to_date('20161215', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 10 / Milestone 3 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Tyson King'
           , 'Train IT personnel in updated app' 
           , 'Train selected IT staff in how to use the apps.' 
           , l_milestone_id 
           , 'Y' 
           , to_date('20161212', 'YYYYMMDD') + l_add_days 
           , to_date('20161112', 'YYYYMMDD') + l_add_days 
           , 1000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Eva Jelinek'
           , 'Monitor IT Staff on IT Management Apps' 
           , 'Monitor IT staff and provide assistance as necessary.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161213', 'YYYYMMDD') + l_add_days 
           , to_date('20161216', 'YYYYMMDD') + l_add_days 
           , 4000
          ); 
    
        -- Insert Milestone 4 for Project 10 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Complete Final Development of IT Management apps' 
           , 'Enhance the application further to meet outstanding requirements.' 
           , to_date('20161225', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 10 / Milestone 4 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Brock Shilling'
           , 'Implement additional feature functions to IT Management Apps' 
           , 'Enhance existing features based on responses from IT staff.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161217', 'YYYYMMDD') + l_add_days 
           , to_date('20161222', 'YYYYMMDD') + l_add_days 
           , 6000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Eva Jelinek'
           , 'Implement outstanding feature functions' 
           , 'Add missing features outlined in responses from IT staff.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161217', 'YYYYMMDD') + l_add_days 
           , to_date('20161221', 'YYYYMMDD') + l_add_days 
           , 5500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Harold Youngblood'
           , 'Load new production data for final IT Management Apps' 
           , 'Ensure all data required for production roll out are inserted and maintained.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161223', 'YYYYMMDD') + l_add_days 
           , to_date('20161223', 'YYYYMMDD') + l_add_days 
           , 1000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Daniel Lee James'
           , 'Test Production-Ready IT Management Apps' 
           , 'Do full scale testing on the IT Management Apps.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161224', 'YYYYMMDD') + l_add_days 
           , to_date('20161225', 'YYYYMMDD') + l_add_days 
           , 1000
          ); 
    
        -- Insert Milestone 5 for Project 10 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Roll out final IT Management app' 
           , 'Go-Live for the IT Management application.' 
           , to_date('20161230', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 10 / Milestone 5 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Harold Youngblood'
           , 'Install revised IT Management apps onto Production Server' 
           , 'Install the revised database objects and application(s) into the production environment.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161226', 'YYYYMMDD') + l_add_days 
           , to_date('20161226', 'YYYYMMDD') + l_add_days 
           , 1000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Harold Youngblood'
           , 'Configure production data load procedures' 
           , 'Install and test data load procedures from internal and external data sources into production environment.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161227', 'YYYYMMDD') + l_add_days 
           , to_date('20161228', 'YYYYMMDD') + l_add_days 
           , 2000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Bernard Jackman'
           , 'Announce Rollout of revised IT Management apps to all IT staff' 
           , 'Email or call IT staff to inform them of the new application and details on new features.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161229', 'YYYYMMDD') + l_add_days 
           , to_date('20161229', 'YYYYMMDD') + l_add_days 
           , 1000
          ); 
        commit;
    end;
/
 
 
declare
        l_add_days          number;
        l_project_id        number;
        l_milestone_id      number;
        l_task_id           number; 
        l_comment_id        number;
begin
        --------------------------- 
        --<< Insert Project 11 >>-- 
        --------------------------- 
        l_add_days := sysdate - to_date('20170101','YYYYMMDD'); 
        insert into projects 
          (  name 
           , description 
           , project_lead 
           , budget
           , completed_date 
           , status_id 
          ) 
          values 
          (  'Develop Bug Tracking Application' 
           , 'Develop an application to track bugs and their resolution.' 
           , 'Lucille Beatie' 
           , 18000 
           , to_date('20161225', 'YYYYMMDD') + l_add_days
           , 3
          )
          returning id into l_project_id; 
    
        -- Insert Milestone 1 for Project 11 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Review Bug Tracker Packaged App' 
           , 'Work with key stakeholders to prioritize improvements to the default Packaged App.' 
           , to_date('20161211', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 11 / Milestone 1 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Miyazaki Yokohama'
           , 'Install Bug Tracker Packaged App' 
           , 'Install the packaged app and turn on the appropriate options.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161210', 'YYYYMMDD') + l_add_days 
           , to_date('20161110', 'YYYYMMDD') + l_add_days 
           , 1000
          )
          returning id into l_task_id; 
    
        insert into project_task_todos
          (  project_id
           , task_id
           , assignee
           , name
           , description
           , is_complete_yn
          )
        values
          (  l_project_id
           , l_task_id
           , 'Miyazaki Yokohama'
           , 'Contact key stakeholders'
           , 'Get meetings scheduled for the key stakeholders.'
           , 'Y'
          );
    
        insert into project_task_todos
          (  project_id
           , task_id
           , assignee
           , name
           , description
           , is_complete_yn
          )
        values
          (  l_project_id
           , l_task_id
           , 'Miyazaki Yokohama'
           , 'Prepare presentation for stakeholders'
           , 'Determine the current functionality to present to key stakeholders.'
           , 'Y'
          );
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Mei Yu'
           , 'Define external bug data feeds' 
           , 'Specify the data sources for bug data.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161211', 'YYYYMMDD') + l_add_days 
           , to_date('20161212', 'YYYYMMDD') + l_add_days 
           , 2500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Design Bug Tracker Look and Feel' 
           , 'Define how data will be displayed on bugs.' 
           , l_milestone_id 
           , 'Y' 
           , to_date('20161211', 'YYYYMMDD') + l_add_days 
           , to_date('20161213', 'YYYYMMDD') + l_add_days 
           , 2000
          ); 
    
    
        -- Insert Milestone 2 for Project 11 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Deliver First-Cut of Bug Tracker' 
           , 'Create the initial screens and populate with data so key stakeholders can review the initial solution.' 
           , to_date('20161217', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 11 / Milestone 2 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Miyazaki Yokohama'
           , 'Define necessary customizations to the Bug Tracker app' 
           , 'Add the additional attributes required based on the bug information being delivered.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161213', 'YYYYMMDD') + l_add_days 
           , to_date('20161214', 'YYYYMMDD') + l_add_days 
           , 2000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Mei Yu'
           , 'Populate Data Structures for Bug Tracker' 
           , 'Upload existing bug data from external sources into local tables.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161215', 'YYYYMMDD') + l_add_days 
           , to_date('20161215', 'YYYYMMDD') + l_add_days 
           , 1500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Customize the Bug Tracker app' 
           , 'Use built-in functionality and Theme Roller to tweak the application.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161215', 'YYYYMMDD') + l_add_days 
           , to_date('20161215', 'YYYYMMDD') + l_add_days 
           , 500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Lucille Beatie'
           , 'Present First Cut to stakeholders' 
           , 'Walk key stakeholders through the initial app and obtain their feedback.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161217', 'YYYYMMDD') + l_add_days 
           , to_date('20161217', 'YYYYMMDD') + l_add_days 
           , 500
          ); 
    
        -- Insert Milestone 3 for Project 11 
        insert into project_milestones 
          (  project_id 
           , name 
           , description 
           , due_date 
          ) 
        values 
          (  l_project_id 
           , 'Deliver Final Customer Tracker Application' 
           , 'Deliver the completed application to the business.' 
           , to_date('20161224', 'YYYYMMDD') + l_add_days 
          )
          returning id into l_milestone_id; 
    
        -- Insert Tasks for Project 11 / Milestone 3 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Miyazaki Yokohama'
           , 'Define additional tables / columns within the Bug Tracker app' 
           , 'Add the extra bug attributes required based on feedback.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161219', 'YYYYMMDD') + l_add_days 
           , to_date('20161120', 'YYYYMMDD') + l_add_days 
           , 2000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Mei Yu'
           , 'Final upload of Data Structures for Bug Tracker' 
           , 'Reload bug data from external sources into local tables.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161221', 'YYYYMMDD') + l_add_days 
           , to_date('20161222', 'YYYYMMDD') + l_add_days 
           , 1500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Customize the Bug Tracker app based on First-Cut feedback' 
           , 'Use built-in functionality and Theme Roller to tweak the application.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161222', 'YYYYMMDD') + l_add_days 
           , to_date('20161222', 'YYYYMMDD') + l_add_days 
           , 500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Miyazaki Yokohama'
           , 'Train staff on use of Bug Tracker' 
           , 'Walk key users through the application.' 
           , l_milestone_id
           , 'Y' 
           , to_date('20161224', 'YYYYMMDD') + l_add_days 
           , to_date('20161225', 'YYYYMMDD') + l_add_days 
           , 2500
          ); 
        commit;
    end;
/
 
 
declare
        l_add_days          number;
        l_project_id        number;
        l_milestone_id      number;
        l_task_id           number; 
        l_comment_id        number;
begin
        --------------------------- 
        --<< Insert Project 12 >>-- 
        --------------------------- 
        l_add_days := sysdate - to_date('20170101','YYYYMMDD'); 
        insert into projects 
          (  name 
           , description 
           , project_lead 
           , budget
           , completed_date 
           , status_id 
          ) 
          values 
          (  'Implement Customer Success Application' 
           , 'Implement an application to track and display customer success stories and quotes.' 
           , 'Bernard Jackman'
           , 25000
           , to_date('20161231', 'YYYYMMDD') + l_add_days 
           , 3 
          )
          returning id into l_project_id; 
    
        -- Insert Tasks for Project 12 
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Bernard Jackman'
           , 'Define main requirements for customer success application.' 
           , 'Define the scope and timelines for the development of the app.' 
           , null 
           , 'Y' 
           , to_date('20161217', 'YYYYMMDD') + l_add_days 
           , to_date('20161218', 'YYYYMMDD') + l_add_days 
           , 2000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Tyson King'
           , 'Finalize Customer Success Data Model' 
           , 'Define the data model for new and existing entities required to support customer success input and reporting.' 
           , null
           , 'Y' 
           , to_date('20161219', 'YYYYMMDD') + l_add_days 
           , to_date('20161221', 'YYYYMMDD') + l_add_days 
           , 2500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Madison Smith'
           , 'Finalize User Experience' 
           , 'Write developer standards on UX and development standards on how the company will acquire and report on customer success.' 
           , null
           , 'Y' 
           , to_date('20161219', 'YYYYMMDD') + l_add_days 
           , to_date('20161220', 'YYYYMMDD') + l_add_days 
           , 2500
          ); 
    
         insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Brock Shilling'
           , 'Define Admin Screens for Customer Success App' 
           , 'Define screens to maintain all of the base tables for the Customer Success apps.' 
           , null
           , 'Y' 
           , to_date('20161121', 'YYYYMMDD') + l_add_days 
           , to_date('20161222', 'YYYYMMDD') + l_add_days 
           , 1500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Eva Jelinek'
           , 'Populate Data Structures for Customer Success App' 
           , 'Upload actual data provided from other IT systems.' 
           , null
           , 'Y' 
           , to_date('20161222', 'YYYYMMDD') + l_add_days 
           , to_date('20161222', 'YYYYMMDD') + l_add_days 
           , 1000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Tyson King'
           , 'Design production screens for the customer to provide quotes and success stories' 
           , 'Implement fully functional and complete screens to allow customers to provide input.' 
           , null
           , 'Y' 
           , to_date('20161223', 'YYYYMMDD') + l_add_days 
           , to_date('20161225', 'YYYYMMDD') + l_add_days 
           , 2500
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Eva Jelinek'
           , 'Design internal screens for collecting information and analyzing results' 
           , 'Develop data entry and reporting screens to manage Customer Success.' 
           , null
           , 'Y' 
           , to_date('20161223', 'YYYYMMDD') + l_add_days 
           , to_date('20161226', 'YYYYMMDD') + l_add_days 
           , 4000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Daniel Lee James'
           , 'Test Customer Success internal / external apps' 
           , 'Do full scale testing on both the customer facing and internal-only screens.' 
           , null
           , 'Y' 
           , to_date('20161227', 'YYYYMMDD') + l_add_days 
           , to_date('20161228', 'YYYYMMDD') + l_add_days 
           , 2000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Harold Youngblood'
           , 'Contact initial customers to educate them on providing quotes and success stories' 
           , 'Work off a call list to email or call the beta customers and monitor their responses.' 
           , null
           , 'Y' 
           , to_date('20161227', 'YYYYMMDD') + l_add_days 
           , to_date('20161230', 'YYYYMMDD') + l_add_days 
           , 4000
          ); 
    
        insert into project_tasks 
          (  project_id 
           , assignee 
           , name 
           , description 
           , milestone_id 
           , is_complete_yn 
           , start_date 
           , end_date 
           , cost
          ) 
        values 
          (  l_project_id 
           , 'Bernard Jackman'
           , 'Announce Customer Success app to all customers and staff' 
           , 'Email all current customers and staff to inform them of the new application and instructions on how to get started.' 
           , null
           , 'Y' 
           , to_date('20161231', 'YYYYMMDD') + l_add_days 
           , to_date('20161231', 'YYYYMMDD') + l_add_days 
           , 1000
          ); 
        commit;
end;
/

GRANT READ ON PROJECTS.PROJECT_STATUS TO LIVE_SQL_SAMPLE_SCHEMAS_USER;
GRANT READ ON PROJECTS.PROJECTS TO LIVE_SQL_SAMPLE_SCHEMAS_USER;
GRANT READ ON PROJECTS.PROJECT_MILESTONES TO LIVE_SQL_SAMPLE_SCHEMAS_USER;
GRANT READ ON PROJECTS.PROJECT_TASKS TO LIVE_SQL_SAMPLE_SCHEMAS_USER;
GRANT READ ON PROJECTS.PROJECT_TASK_TODOS TO LIVE_SQL_SAMPLE_SCHEMAS_USER;
GRANT READ ON PROJECTS.PROJECT_TASK_LINKS TO LIVE_SQL_SAMPLE_SCHEMAS_USER;
GRANT READ ON PROJECTS.PROJECTS_COMPLETED_V TO LIVE_SQL_SAMPLE_SCHEMAS_USER;
