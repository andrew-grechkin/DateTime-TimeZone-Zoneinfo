use v5.40;
use experimental qw(class);

class DateTime::TimeZone::Zoneinfo::DynamicTransition {
    use overload
        '""'       => sub($self, @) {return $self->to_string},
        'bool'     => sub {return true},
        'fallback' => true;

    use Carp qw();

    field $epoch : param : reader;
    field $sysv  : param : reader;

    sub from_footer($class, $epoch, $version, $footer) {
        require DateTime::TimeZone::SystemV;
        DateTime::TimeZone::SystemV->VERSION('0.009');
        return $class->new(
            epoch => $epoch,
            sysv  => DateTime::TimeZone::SystemV->new(
                system => $version >= 3 ? 'tzfile3' : 'posix',
                recipe => $footer,
            ),
        );
    }

    method to_string() {
        return sprintf('[%16d] %s', int($self->epoch), $self->sysv->name);
    }

    method abbreviation($tm) {return $sysv->short_name_for_datetime($tm)}
    method is_dst($tm)       {return $sysv->is_dst_for_datetime($tm)}

    method offset($tm) {
        my $offset = $sysv->offset_for_datetime($tm);
        return $offset if defined $offset;
        Carp::croak("Local time does not exist (due to DST gap): $tm");
    }
}
