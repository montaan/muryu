ALTER TABLE itemtexts ADD COLUMN fti_vector tsvector;
CREATE TRIGGER tsvectorupdate BEFORE UPDATE OR INSERT ON itemtexts
    FOR EACH ROW EXECUTE PROCEDURE tsearch2(fti_vector, text);

CREATE INDEX itemtexts_fti_idx ON itemtexts USING gist(fti_vector);
VACUUM FULL ANALYZE;
