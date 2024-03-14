select 
	  	  
	 /*info from the activity_events table*/
	  convert_timezone('EST', ae.created_at) as created_at 
	 ,ae.name 		as update_type
	 ,ae.target_type
	 ,ae.item_type
	 
	 /*basic info on the target entity, where applicable*/
	 ,e.interact_id 				 as worker_interact_id
	 ,e.first_name ||' '|| coalesce (e.last_name,'') as worker_name
	 
	 /*basic info from users table*/
	 ,u.first_name ||' '|| u.last_name 	as user_name
	 ,u.email 				as user_email
	 ,u.role 				as user_role
	 
	 /*campaign info*/
	 ,c.name as campaign_name
	 ,u2.first_name ||' '|| u2.last_name 	as support_user
	 	 
	/*for tags applied, derive from "payload" the field that the applied tag belongs to*/
	,case 	when ae.name = 'create_entity_tags' then json_extract_path_text(json_extract_path_text(json_extract_path_text(payload,'taggableLogbook'),'category'),'name') 
 	  		else null end as field_updated
	 
 	/*derive from "payload" a "value" field to reflect the update made -- the tag applied, assessment made, note entered, etc*/
 	,case 	when ae.name = 'create_assessment' then json_extract_path_text(json_extract_path_text(ae.payload, 'assessment'),'level')::text 
	 		when ae.name = 'create_entity_global_note' then json_extract_path_text(json_extract_path_text(ae.payload, 'note'),'text')::text
	 		when ae.name = 'create_entity_tags' then json_extract_path_text(json_extract_path_text(json_extract_path_text(payload,'taggableLogbook'),'tag'),'name')::text
	  		else null end as value
	 
	 /*derive from "payload" a "value" field to reflect the update made -- the tag applied, assessment made, note entered, etc*/
	 ,case 	when ae.name = 'create_assessment' then json_extract_path_text(json_extract_path_text(ae.payload, 'before'),'level')::text else null end as previous_assessment
	  
	/*flag a list of values in ae."name" as quick-apply operations*/
	,case 	when left(ae.name,4) = 'mass' then 'y' else 'n' end as quick_apply_flag
		
	/*for these quick-apply operations, derive from "payload" a count of entities affected*/
	,case 	when left(ae.name,4) = 'mass' then json_extract_path_text(ae.payload, 'entitiesAffected')::int else 1 end as entities_affected
	
	/*group item_type and name values into an update_category field */						
	,case	when ae.item_type 	= 'GlobalNote' then 'Notes'
			when ae.item_type 	= 'ContactAttempt' then 'Canvassing'
			when ae.item_type 	in ('Address','Email','PhoneNumber','SocialProfile') then 'Contact Info'
			when ae.name		in ('remove_entity_from_campaign','create_campaign_entity') then 'Entities'
			when ae.item_type 	= 'Assessment' or ae.name = 'mass_add_assessment' then 'Assessments'
			when ae.item_type 	= 'FollowUp' or ae.name in ('mass_add_follow_up','mass_complete_follow_up') then 'Follow-Ups'
			when ae.item_type 	= 'TaggableLogbook' or ae.name in ('mass_remove_tags','mass_apply_tags') then 'Tags'			
			when ae.item_type 	in ('EntityConnection','Relationship') or ae.name in ('mass_remove_entity_connection','mass_add_or_update_entity_connection') then 'Connections'
			else 'Other'
			end as update_category
		  
from action_builder.activity_events ae 
	inner join action_builder.campaigns c on ae.campaign_id = c.id
	inner join action_builder.users u on ae.user_id = u.id
	inner join action_builder.users u2 on c.support_user_id = u2.id 
	left join action_builder.entities e on ae.target_id = e.id 
where convert_timezone('EST', ae.created_at) > (current_date - interval '1 year')
