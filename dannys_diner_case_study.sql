-- Danny wants to use the data to answer a few simple questions about his customers, especially about their visiting patterns, how much  money they’ve spent and also which menu items are their 
-- favourite.Having this deeper connection with his customers will help him deliver a better and more personalised experience for his loyal customers.


create table sales (
	customer_id VARCHAR(1),
	order_date date,
	product_id int
);

insert into sales (customer_id, order_date, product_id)
values
('A', '2021-01-01', 1),
('A', '2021-01-01', 2),
('A', '2021-01-07', 2),
('A', '2021-01-10', 3),
('A', '2021-01-11', 3),
('A', '2021-01-11', 3),

('B', '2021-01-01', 2),
('B', '2021-01-02', 2),
('B', '2021-01-04', 1),
('B', '2021-01-11', 1),
('B', '2021-01-16', 3),
('B', '2021-02-01', 3),

('C', '2021-01-01', 3),
('C', '2021-01-01', 3),
('C', '2021-01-07', 3);


create table menu (
product_id int,
product_name VARCHAR(50),
price int
);

insert into menu (product_id, product_name, price)
values
(1, 'sushi', 10),
(2, 'curry', 15),
(3, 'ramen', 12);


create table members (
customer_id varchar(1), join_date date
);

insert into members (customer_id, join_date)
values
('A', '2021-01-07'),
('B', '2021-01-09');


select * from sales;
select * from menu;
select * from members;


-- What is the total amount each customer spent at the restaurant?
-- How many days has each customer visited the restaurant?
-- What was the first item from the menu purchased by each customer?
-- What is the most purchased item on the menu and how many times was it purchased by all customers?
-- Which item was the most popular for each customer?
-- Which item was purchased first by the customer after they became a member?
-- Which item was purchased just before the customer became a member?
-- What is the total items and amount spent for each member before they became a member?
-- If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
-- In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?


--Q1. What is the total amount each customer spent at the restaurant?
select 
	s.customer_id,  
	sum(m.price) as total_spent
from sales as s 
join menu as m
	on s.product_id = m.product_id
group by s.customer_id 
order by s.customer_id;


--Q2. How many days has each customer visited the restaurant?
select 
	customer_id, 
	count(distinct order_date) as visited_restaurant
from sales 
group by customer_id
order by customer_id;


--Q3. What was the first item from the menu purchased by each customer?
with cte_order as(
	select 
		s.customer_id,
		m.product_name,
		row_number()over(
			partition by s.customer_id
				order by 
					s.order_date, 
					s.product_id
	 	) as item_order
		from sales as s 
		join menu as m
		on s.product_id = m.product_id
)
select * from cte_order
where item_order = 1;


--Q4. What is the most purchased item on the menu and how many times was it purchased 
-- by all customers?
select 
	m.product_name, 
	count(s.product_id) as order_count
from sales as s 
inner join menu as m
	on s.product_id = m.product_id
group by 
	m.product_name 
order by order_count desc
limit 1;


--Q5. Which item was the most popular for each customer?
with cte_order_count as (
  select
    s.customer_id,
    m.product_name,
    count(*) as order_count
  from sales as s
  join menu as m
    on s.product_id = m.product_id
  group by
    customer_id,
    product_name
  order by
    customer_id,
    order_count desc
),
cte_popular_rank as (
  select
    *,
    rank() over(partition by customer_id order by order_count desc) as rank
  from cte_order_count
)
select * from cte_popular_rank
where rank = 1;


--Note: Before answering question 6-10, I created a membership_validation table to validate only those customers joining in the membership program:
drop table if exists membership_validation;
create temp table membership_validation as 
select
	s.customer_id,
	s.order_date,
	m.product_name,
	m.price,
	mem.join_date,
	case when s.order_date >= mem.join_date
		then 'X'
		else ''
		end as membership
from sales as s 
inner join menu as m
	on s.product_id=m.product_id
left join members as mem
	on s.customer_id=mem.customer_id
	where join_date is not null
	order by
	customer_id,
	order_date;

select * from membership_validation;


--Q6. Which item was purchased first by the customer after they became a member?
with cte_first_after_mem as (
	select
		customer_id,
		product_name,
		order_date,
		rank() over (
		partition by customer_id
		order by order_date) as purchase_order
	from membership_validation
	where membership = 'X'
)
select * from cte_first_after_mem 
where purchase_order = 1;


-- Q7. Which item was purchased just before the customer became member?
with cte_last_before_mem as (
	select 
		customer_id,
		product_name,
		order_date,
		rank() over (
		partition by customer_id
		order by order_date desc) as purchase_order
	from membership_validation
	where membership = ''
)
select * from cte_last_before_mem 
where purchase_order = 1;


-- Q8. What is the total items and amount spent for each member before they became a member?
select 
	customer_id,
	count(product_name) as total_items,
	sum(price) as amount_spent
from membership_validation
where membership = ''
group by customer_id;


-- Q9. if each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?

select 
	customer_id,
	sum(
	case when product_name <> 'sushi' 
	then price * 10
	else price * 20
	end 
	)as points
from membership_validation
group by customer_id
order by customer_id;


-- Q10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, 
-- not just sushi - how many points do customer A and B have at  the end of january?

--create temp table for days validation within the first week membership
drop table if exists membership_first_week_validation;
create temp table membership_first_week_validation as 
with cte_valid as (
select 
	customer_id,
	order_date,
	product_name,
	price,
	count(*) as order_count,
	case when order_date between join_date and (join_date + 6)
	then 'X'
	else ''
	end as within_first_week
from  membership_validation
group by 
	customer_id,
	order_date,
	product_name,
	price,
	join_date
order by
	customer_id,
	order_date
	)
select * from cte_valid
where order_date < '2021-02-01';
select * from membership_first_week_validation;

--create temp table for points calculation only in the first week of membership
drop table if exists membership_first_week_points;
create temp table membership_first_week_points as
with cte_first_week_count as (
  select * from membership_first_week_validation
  where within_first_week = 'X'
)
select
  customer_id,
  sum(
  case when within_first_week = 'X'
  then (price * order_count * 20)
  else (price * order_count * 10)
  end
  ) as total_points
from cte_first_week_count
group by customer_id;
--inspect table results
select * from membership_first_week_points;

--create temp table for points calculation excluded the first week membership (before membership + after the first week membership)
drop table if exists membership_non_first_week_points;
create temp table membership_non_first_week_points as 
with cte_first_week_count as (
	select * from membership_first_week_validation
	where within_first_week = ''
)
select 
	customer_id,
	sum(case when product_name = 'sushi'
	then (price * order_count * 20)
	else (price * order_count * 10)
	end
	) as total_points
from cte_first_week_count
group by customer_id;

select * from membership_non_first_week_points;

--perform table union to aggregate our point values from both point calculation tables, then use SUM aggregate function to get our result
with cte_union AS (
  SELECT * FROM membership_first_week_points
  UNION
  SELECT * FROM membership_non_first_week_points
)
SELECT
  customer_id,
  SUM(total_points)
FROM cte_union
GROUP BY customer_id
ORDER BY customer_id;
