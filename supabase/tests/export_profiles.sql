-- Export actual SQL-role fixture responses; all inserted data rolls back.
begin;
create temp table profile_exports(name text, owner text, response jsonb);
grant insert,select on profile_exports to authenticated;
insert into auth.users values('e2000000-0000-4000-8000-000000000001'),('e2000000-0000-4000-8000-000000000002');
set local role authenticated;
select set_config('request.jwt.claim.sub','e2000000-0000-4000-8000-000000000001',true);
insert into profile_exports select 'new-A','e2000000-0000-4000-8000-000000000001',public.ensure_profile('{}');
update public.profiles set display_name='学習者',preferred_jlpt='N4',daily_target_minutes=150,timezone='Asia/Tokyo';
insert into profile_exports select 'existing-A','e2000000-0000-4000-8000-000000000001',public.ensure_profile('{}');
insert into profile_exports select 'invalid-fields','e2000000-0000-4000-8000-000000000001',public.ensure_profile('{"id":"e2000000-0000-4000-8000-000000000002"}');
select set_config('request.jwt.claim.sub','e2000000-0000-4000-8000-000000000002',true);
insert into profile_exports select 'new-B','e2000000-0000-4000-8000-000000000002',public.ensure_profile('{}');
select set_config('request.jwt.claim.sub','',true);
insert into profile_exports select 'no-identity','e2000000-0000-4000-8000-000000000002',public.ensure_profile('{}');
reset role;
select 'PROFILE_WIRE:'||jsonb_build_object('version','nd-own-profile-1','cases',jsonb_agg(jsonb_build_object('name',name,'owner',owner,'response',response) order by name))::text from profile_exports;
rollback;
