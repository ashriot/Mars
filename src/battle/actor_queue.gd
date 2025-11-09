extends Control
class_name ActorQueue

func setup(actor: ActorCard):
	$NameLabel.text = actor.current_stats.actor_name
	$CtLabel.text = str(int(actor.current_ct / 10)) + "%"
