requires 'perl', '5.008001';

requires 'DBIx::Sunny', '0.21';
requires 'SQL::NamedPlaceholder', '0.03';
requires 'SQL::Maker', '1.12';
requires 'parent';
requires 'DBI','1.630';

on 'test' => sub {
    requires 'DBD::SQLite';
    requires 'Test::More', '0.98';
};

