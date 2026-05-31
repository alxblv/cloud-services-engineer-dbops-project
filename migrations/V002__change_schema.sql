ALTER TABLE product add COLUMN price double precision;

ALTER TABLE product ADD CONSTRAINT product_id PRIMARY KEY (id);

DROP TABLE product_info;

ALTER TABLE orders add COLUMN date_created date default current_date;

ALTER TABLE orders ADD CONSTRAINT order_id PRIMARY KEY (id);

DROP TABLE orders_date;

ALTER TABLE order_product
ADD CONSTRAINT product_id_foreign_key
FOREIGN KEY (product_id)
REFERENCES product(id);

ALTER TABLE order_product
ADD CONSTRAINT order_id_foreign_key
FOREIGN KEY (order_id)
REFERENCES orders(id);