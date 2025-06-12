/*This query checks for duplicate emails in an Action Builder campaign,
 * finds the potentially duplicate entities that share those emails, and 
 * generates link a link to merge these entities and a link to each profile.
 * 
 * This query only returns the two oldest entities with a given shared email.*/

/*set the campaign you want to review, and your AB subdomain*/
with variables as (
	select 
		 17 	as campaign_id
		,1		as entity_type_id
		,'cwa' 	as subdomain
)

/*find all emails that occur more than once in the campaign*/
,duplicate_emails as (
	select 
		 em.email
		,count(*)
	from entities e 
		inner join campaigns_entities ce on e.id = ce.entity_id		
		inner join emails em on e.id = em.owner_id 
	where 
			ce.campaign_id = (select campaign_id from variables)
		and e.entity_type_id = (select entity_type_id from variables)
		and em.status <> 'bad'
	group by em.email
	having count(*) > 1
)

/*find all the entities with duplicated emails and use row_number() to rank them*/
,potential_duplicate_entities as (
	select
		 em.email
		,e.id
		,e.first_name
		,e.middle_name
		,e.nickname
		,e.last_name
		,row_number() over (partition by de.email order by e.created_at asc) as row_no
	from entities e 
		inner join campaigns_entities ce on e.id = ce.entity_id	
		inner join emails em on e.id = em.owner_id 
		inner join duplicate_emails de on em.email = de.email
	where
			ce.campaign_id = (select campaign_id from variables)
		and e.entity_type_id = (select entity_type_id from variables)
)

/*join the first and second-ranked entities with shared info to review and merge*/
select
	 p1.email
	,concat(p1.first_name||' ', p1.middle_name||' ', '"' ||p1.nickname||'" ', p1.last_name) as entity_1_name
	,concat(p2.first_name||' ', p2.middle_name||' ', '"' ||p2.nickname||'" ', p2.last_name) as entity_2_name
	,concat('https://',(select subdomain from variables),'.actionbuilder.org/entity/merge?campaignId=',(select campaign_id from variables),'&targetEntityId=',p1.id,'&sourceEntityId=',p2.id) as entity_merge_link
	,concat('https://',(select subdomain from variables),'.actionbuilder.org/entity/view/',p1.id,'/profile?campaignId=',(select campaign_id from variables)) as entity_1_profile_link
	,concat('https://',(select subdomain from variables),'.actionbuilder.org/entity/view/',p2.id,'/profile?campaignId=',(select campaign_id from variables)) as entity_2_profile_link
from potential_duplicate_entities p1
	inner join potential_duplicate_entities p2 on p1.email = p2.email
where 
		p1.row_no = 1
	and p2.row_no = 2