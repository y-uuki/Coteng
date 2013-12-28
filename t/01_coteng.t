use strict;
use warnings;

use t::cotengtest;
use Test::More;

subtest use => sub {
    use_ok "Coteng";
};

subtest new => sub {
    my $coteng = Coteng->new({
        connect_info => {
            db_master => {
                dsn     => 'dbi:SQLite::memory:',
                user    => 'nobody',
                passwd  => 'nobody',
            },
            db_slave => {
                dsn     => 'dbi:SQLite::memory:',
                user    => 'nobody',
                passwd  => 'nobody',
            },
        },
        driver_name => 'SQLite',
        root_dbi_class => "Scope::Container::DBI",
    });

    if (ok $coteng) {
        isa_ok $coteng, "Coteng";
        is_deeply $coteng->{connect_info}{db_master}, {
            dsn     => 'dbi:SQLite::memory:',
            user    => 'nobody',
            passwd  => 'nobody',
        };
        is_deeply $coteng->{connect_info}{db_slave}, {
            dsn     => 'dbi:SQLite::memory:',
            user    => 'nobody',
            passwd  => 'nobody',
        };
        is $coteng->{driver_name}, 'SQLite';
        is $coteng->{root_dbi_class}, "Scope::Container::DBI";
    }
};

subtest db => sub {
    my $coteng = Coteng->new({
        connect_info => {
            db_master => {
                dsn => 'dbi:SQLite::memory:',
            },
            db_slave => {
                dsn => 'dbi:SQLite::memory:',
            },
        },
        driver_name => 'SQLite',
    });

    isa_ok $coteng->db('db_master'), 'Coteng';
    is $coteng->current_dbh, $coteng->{_dbh}{db_master};

    isa_ok $coteng->db('db_slave'),  'Coteng';
    is $coteng->current_dbh, $coteng->{_dbh}{db_slave};
};

subtest dbh => sub {
    my $coteng = Coteng->new({
        connect_info => {
            db_master => {
                dsn => 'dbi:SQLite::memory:',
            },
            db_slave => {
                dsn => 'dbi:SQLite::memory:',
            },
        },
        driver_name => 'SQLite',
    });
    isa_ok $coteng->dbh('db_master'), 'DBIx::Sunny::db';
    isa_ok $coteng->dbh('db_slave'),  'DBIx::Sunny::db';
};


my $dbh = setup_dbh();
create_table($dbh);

my $coteng = Coteng->new({
    connect_info => {
        db_master => {
            dsn => 'dbi:SQLite::memory:',
        },
    },
    driver_name => 'SQLite',
});
$coteng->{current_dbh} = $dbh;

subtest single => sub {
    my $id = insert_mock($dbh, name => "mock1");

    subtest 'without class' => sub {
        my $row = $coteng->single(mock => {
            id => $id,
        });
        isa_ok $row, "HASH";
        is $row->{name}, "mock1";
    };

    subtest 'with class' => sub {
        my $row = $coteng->single(mock => {
            id => $id,
        }, 'Coteng::Model::Mock');
        isa_ok $row, "Coteng::Model::Mock";
        is $row->name, "mock1";
    };
};

subtest search => sub {
    my $id = insert_mock($dbh, name => "mock2");

    subtest 'without class' => sub {
        my $rows = $coteng->search(mock => {
            name => "mock2",
        });
        isa_ok $rows, "ARRAY";
        is scalar(@$rows), 1;
        isa_ok $rows->[0], "HASH";
    };

    subtest 'with class' => sub {
        my $rows = $coteng->search(mock => {
            id => $id,
        }, 'Coteng::Model::Mock');
        is scalar(@$rows), 1;
        isa_ok $rows->[0], "Coteng::Model::Mock";
        is $rows->[0]->name, "mock2";
    };
};

subtest fast_insert => sub {
    my $id = $coteng->fast_insert(mock => {
        name => "mock3",
    });

    my $row = $coteng->single(mock => {
        name => "mock3",
    });
    if (ok $row) {
        is $id, $row->{id};
    }
};

subtest insert => sub {
    my $row = $coteng->insert(mock => {
        name => "mock4",
    });

    my $found_row = $coteng->single(mock => {
        name => "mock4",
    });
    if (ok $found_row) {
        is_deeply $row, $found_row;
    }
};

subtest update => sub {
    my $id = $coteng->fast_insert(mock => {
        name => "mock5",
    });

    my $updated_row_count = $coteng->update(mock => {
        name => "mock5-heyhey",
    }, { id => $id });

    my $found_row = $coteng->single(mock => {
        name => "mock5",
    });
    ok !$found_row;
    $found_row = $coteng->single(mock => {
        name => "mock5-heyhey",
    });
    ok $found_row;

    is $updated_row_count, 1;
};

subtest delete => sub {
    my $id = $coteng->fast_insert(mock => {
        name => "mock6",
    });

    my $deleted_row_count = $coteng->delete(mock => { id => $id });

    my $found_row = $coteng->single(mock => {
        name => "mock6",
    });
    ok !$found_row;
    is $deleted_row_count, 1;
};

subtest single_named => sub {
    my $id = $coteng->fast_insert(mock => {
        name => "mock7",
    });

    subtest 'without class' => sub {
        my $row = $coteng->single_named(q[
            SELECT * FROM mock WHERE id = :id
        ], { id => $id });

        if (ok $row) {
            isa_ok $row, "HASH";
            is $row->{id}, $id;
        }
    };

    subtest 'with class' => sub {
        my $row = $coteng->single_named(q[
            SELECT * FROM mock WHERE id = :id
        ],{
            id => $id,
        }, 'Coteng::Model::Mock');

        if (ok $row) {
            isa_ok $row, "Coteng::Model::Mock";
            is $row->id, $id;
        }
    };
};

subtest single_by_sql => sub {
    my $id = $coteng->fast_insert(mock => {
        name => "mock8",
    });

    subtest 'without class' => sub {
        my $row = $coteng->single_by_sql(q[
            SELECT * FROM mock WHERE id = ?
        ], [ $id ]);

        if (ok $row) {
            isa_ok $row, "HASH";
            is $row->{id}, $id;
        }
    };

    subtest 'with class' => sub {
        my $row = $coteng->single_by_sql(q[
            SELECT * FROM mock WHERE id = ?
        ], [ $id ], "Coteng::Model::Mock");

        if (ok $row) {
            isa_ok $row, "Coteng::Model::Mock";
            is $row->id, $id;
        }
    };
};

subtest search_named => sub {
    my $id = $coteng->fast_insert(mock => {
        name => "mock9",
    });

    subtest 'without class' => sub {
        my $rows = $coteng->search_named(q[
            SELECT * FROM mock WHERE id = :id
        ], { id => $id });

        isa_ok $rows, "ARRAY";
        is scalar(@$rows), 1;
        isa_ok $rows->[0], "HASH";
    };

    subtest 'with class' => sub {
        my $rows = $coteng->search_named(q[
            SELECT * FROM mock WHERE id = :id
        ], { id => $id }, "Coteng::Model::Mock");

        isa_ok $rows, "ARRAY";
        is scalar(@$rows), 1;
        isa_ok $rows->[0], "Coteng::Model::Mock";
    };
};

subtest search_by_sql => sub {
    my $id = $coteng->fast_insert(mock => {
        name => "mock10",
    });

    subtest 'without class' => sub {
        my $rows = $coteng->search_by_sql(q[
            SELECT * FROM mock WHERE id = ?
        ], [ $id ]);

        isa_ok $rows, "ARRAY";
        is scalar(@$rows), 1;
        isa_ok $rows->[0], "HASH";
    };

    subtest 'with class' => sub {
        my $rows = $coteng->search_by_sql(q[
            SELECT * FROM mock WHERE id = ?
        ], [ $id ], "Coteng::Model::Mock");

        isa_ok $rows, "ARRAY";
        is scalar(@$rows), 1;
        isa_ok $rows->[0], "Coteng::Model::Mock";
    };
};

subtest execute => sub {
    $coteng->execute(q[
        INSERT INTO mock (name) VALUES (:name)
    ], { name => 'mock11' });

    my $found_row = $coteng->single(mock => {
        name => 'mock11',
    });
    is $found_row->{id}, $coteng->current_dbh->last_insert_id;
};


done_testing;
