use v6;

class PageRef {
  has Str $.namespace;
  has Str $.title;

  multi method new(Str:D :$namespace, Str:D :$title) {
    self.bless(:$namespace, :$title);
  }

  multi method new(Str:D :$page) {
    $_ = $page;
    s:g/'|'//;
    if (/^(.*) <[\.\/]> (.*)$/) {
      self.bless(:namespace($0 eq "@" ?? "Tropers" !! ~$0), :title(~$1));
    } else {
      self.bless(:namespace("Main"), :title($page));
    }
  }

  method gist { "$.namespace/$.title".return }
}

role DOM::Node {}
role DOM::Link does DOM::Node {}
role DOM::Align does DOM::Node {}
class DOM::Doc does DOM::Node { has DOM::Node @.children; }
role DOM::HasBody does DOM::Node { has DOM::Doc $.body; }
role DOM::HasLevel does DOM::HasBody { has Int $.level; }

class DOM::Text does DOM::Node { has Str $.text; }
class DOM::Para does DOM::HasBody {}

class DOM::Quote does DOM::HasLevel { }
class DOM::QuoteBlock does DOM::HasBody { }

class DOM::ExtLink does DOM::HasBody does DOM::Link { has Str $.url; }
class DOM::WikiLink does DOM::HasBody does DOM::Link { has PageRef $.target; }
class DOM::Image does DOM::Node does DOM::Link { has Str $.url; }

class DOM::List does DOM::Node { has Bool $.is-ordered; has DOM::Doc @.items; }

class DOM::Center does DOM::HasBody does DOM::Align { }
class DOM::RTL does DOM::HasBody does DOM::Align { }

role DOM::H does DOM::Node { }

class DOM::WMGHeader does DOM::HasBody does DOM::H { }
class DOM::Header does DOM::HasBody does DOM::H { }
class DOM::Heading does DOM::HasLevel does DOM::H { }

class DOM::Folder does DOM::HasBody { has DOM::Doc $.title; }
class DOM::HLine does DOM::Node { }

role DOM::Tag does DOM::Node { has Str $.tag; }
class DOM::SingleTag does DOM::Tag { }

