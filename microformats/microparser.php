<?php


class Microparser {

    private $rules;


    function Microparser() {
        $rules = func_get_args();
        for ($i = count($rules); $i-- > 0; ) {
            if (is_array($rules[$i]))
                $rules[$i] = MicroparserRule::create($rules[$i]);
        }
        $this->rules = $rules;
    }
    
    
    static function fromArray($rules) {
        $parser = new Microparser();
        for ($i = count($rules); $i-- > 0; ) {
            if (is_array($rules[$i]))
                $rules[$i] = MicroparserRule::create($rules[$i]);
        }
        $parser->rules = $rules;
        return $parser;
    }
    
    
    function &parse(&$node) {
        $state = array();
        $this->parse_($node, $state);
        return $state;
    }


    function &parseTidy(&$node) {
        $parent = null;
        $node = new MicroparserNode(&$node, $parent);
        $state = array();
        $this->parse_($node, $state);
        return $state;
    }


    private function &parse_(&$node, &$state) {
        foreach ($this->rules as $rule) {
            if ($rule->match($node))
                $rule->perform($node, $state);
        }
        if ($node->hasChildren()) {
            foreach ($node->children() as $child)
                $this->parse_($child, $state);
        }
    }
    

}


// The Microparser rule implements two methods. The match() method determines
// which nodes the rule applies to, while the perform() method performs the
// rule's action (e.g. setting a field).
class MicroparserRule {

    // The selector. Implements the method match(node).
    private $selector;
    
    // The action. Implements the method perform(node, state).
    private $action;
    
    
    // Constructs a new rule.
    //
    // selector  The selector object, or a selector string.
    // action    The action object, or action string.
    // subrules  Optional subrules. Only valid when using an action string.
    function MicroparserRule($selector, $action, $subrules = null) {
        if (!$selector)
            throw new Exception("Missing selector argument");
        if (is_string($selector))
            $this->selector = array(MicroparserSelector::create($selector), "match");
        else {
            if (!is_callable($selector))
                throw new Exception("Selector is not a callback");
            $this->selector = $selector;
        }
        if (!$action)
            throw new Exception("Missing action argument");
        if (is_string($action))
            $this->action = array(MicroparserAction::create($action, $subrules), "perform");
        else {
            if (!is_callable($action))
                throw new Exception("Action is not a callback");
            $this->action = $action;
        }
    }
    
    
    // Constructs a new rule using an array. The array must have two elements
    // for the selector and action, and an optional element for subrules.
    //
    // selector  The selector object, or a selector string.
    // action    The action object, or action string.
    // subrules  Optional subrules. Only valid when using an action string.
    static function create($array) {
        if (!$array || !is_array($array) || count($array) < 2)
            throw new Exception("Argument must be an array with selector, action and optional subrules");
        return new MicroparserRule($array[0], $array[1], (count($array) > 2) ? array_slice($array, 2) : null);
    }
    

    // Determines if the rule applies to this node.
    //
    // node  The node to match
    // Returns true if the rule applies to this node
    function match(&$node) {
        return call_user_func($this->selector, &$node);
    }


    // Performs an action on a previously matched node.
    //
    // This function is called with a state object, an array of name-value pairs,
    // which it changes while performing the action.
    //
    // node   A previously matched node
    // state  The state object
    function &perform(&$node, &$state) {
        return call_user_func($this->action, &$node, &$state);
    }

        
}


class MicroparserSelector {

    private $tagName;
    
    private $attrs;
    
    
    static function create($selector) {
        preg_match("/^(\*|[A-Za-z][A-Za-z0-9_\-:]*)?(#[A-Za-z][A-Za-z0-9_\-:]*)?((?:\.[A-Za-z][A-Za-z0-9_\-:]*){0,})((?:\[[A-Za-z][A-Za-z0-9_\-:]*(?:(?:~|\|)?=.*)?\]){0,})\s*(.*)$/", $selector, $matches);
        $tagName = ($matches[1] && $matches[1] != "*") ? $matches[1] : null;
        $attrs = array();
        if ($matches[2])
            $attrs[] = array("id", '=', $matches[2]);
        if ($matches[3]) {
            $tok = strtok($matches[3], ".");
            while ($tok) {
                $attrs[] = array("class", '~', $tok);
                $tok = strtok(".");
            }
        }
        if ($matches[4]) {
            $tok = strtok($matches[4], "[]");
            while ($tok) {
                preg_match("/^([A-Za-z][A-Za-z0-9_\-:]*)((?:~|\|)?=)?(.*)$/", $tok, $attr);
                $attrs[] = array($attr[1], ($attr[2] ? $attr[2][0] : null), $attr[3]);
                $tok = strtok("[]");
            }
        }
        return new MicroparserSelector($tagName, $attrs);
    }
    
    
    private function MicroparserSelector($tagName, $attrs) {
        $this->tagName = $tagName;
        $this->attrs = $attrs;
    }
    
    
    function match(&$node) {
        if ($this->tagName && $this->tagName != $node->tagname())
            return false;
        if ($this->attrs) {
            foreach ($this->attrs as $attr) {
                $name = $attr[0];
                if (!$node->hasAttribute($name))
                    return false;
                switch ($attr[1]) {
                    case '=':
                        if ($node->attribute($name) != $attr[2])
                            return false;
                        break;
                    case '~':
                        $tok = strtok($node->attribute($name), " ");
                        while ($tok) {
                            if ($tok == $attr[2])
                                break;
                            $tok = strtok(" ");
                        }
                        if (!$tok)
                            return false;
                        break;
                    case '|':
                        if (strpos($attr[2], $node->attribute($name)) !== 0)
                            return false;
                        break;
                }
            }
        }
        return true;
    }


}


class MicroparserAction {

    private $name;
    
    private $isArray;
    
    private $extracts;
    
    private $subrules;


    static function create($action, $subrules) {
        preg_match("/^(\w+)(\[\])?(=.*)?$/", $action, $matches);
        $name = $matches[1];
        $isArray = !empty($matches[2]);
        if ($matches[3]) {
            $extracts = array();
            $tok = strtok(substr($matches[3], 1), "|");
            while ($tok) {
                if (preg_match("/^(\w+)\(\)|([A-Za-z][A-Za-z0-9_\-:]*)?@([A-Za-z][A-Za-z0-9_\-:]*)$/", $tok, $matches)) {
                    if ($matches[1]) {
                        $func = $matches[1];
                        if ($func != "text" && $func != "xml" && !is_callable($func))
                            throw new Exception("Cannot call the function {$func}");
                        $extracts[] = array("f", $func);
                    } else
                        $extracts[] = array("a", $matches[2], $matches[3]);
                }
                $tok = strtok("|");
            }
        }
        return new MicroparserAction($name, $isArray, $extracts, $subrules);
    }
    
    
    private function MicroparserAction($name, $isArray, $extracts, $subrules) {
        if (!$name)
            throw new Exception("Value name must be specified");
        $this->name = $name;
        $this->isArray = $isArray;
        $this->extracts = $extracts;
        if ($subrules) {
            if ($this->extracts)
                throw new Exception("Cannot use value extraction and subrules in the same action");
            $this->subrules = Microparser::fromArray($subrules);
        }
    }
    
    
    function perform(&$node, &$state) {
        $value = null;
        if ($this->extracts) {
            foreach ($this->extracts as $extract) {
                if ($extract[0] == "f") {
                    $func = $extract[1];
                    if ($func == "xml")
                        $value = $node->xml();
                    else if ($func == "text")
                        $value = $node->text();
                    else
                        $value = call_user_func($func, $node);
                    break;
                } else {
                    $element = $extract[1];
                    $attr = $extract[2];
                    if (($element == $node->tagname() && $node->hasAttribute($attr)) ||
                        (!$element && $node->hasAttribute($attr))) {
                        $value = $node->attribute($attr);
                        break;
                    }
                }
            }
        } else if ($this->subrules) {
            $value = $this->subrules->parse($node);
        }
        if ($value) {
            if ($this->isArray) {
                if (!isset($state[$this->name]))
                    $state[$this->name] = array($value);
                else
                    $state[$this->name][] = $value;
            } else {
                if (!isset($state[$this->name]))
                    $state[$this->name] = $value;
            }
        }
    }

    
}


class MicroparserNode {

    private $parent;
    
    private $node;
    
    
    function MicroparserNode($node, &$parent) {
        $this->node = $node;
        $this->parent = $parent;
    }
    
    
    function hasChildren() {
        return $this->node->hasChildren();
    }
    
    
    function &children() {
        $children = array();
        $childs = $this->node->child; 
        $count = count($childs);
        for ($i = 0; $i < $count; ++$i)
            $children[] = &new MicroparserNode($childs[$i], $this);
        return $children;
    }
    
    
    function parent() {
        return $this->parent;
    }
    
    
    function tagname() {
        return $this->node->name;
    }
    
    
    function hasAttribute($name) {
        $attr = $this->node->attribute;
        return isset($attr[$name]);
    }


    function attribute($name) {
        $attr = $this->node->attribute;
        return $attr[$name];
    }
    
    
    function xml() {
        return $this->node->value();
    }

    
    function text() {
        if ($this->node->hasChildren()) {
            $value = null;
            foreach ($this->node->child as $child)
                $value .= MicroparserNode::text_(&$child);
            return $value;
        } else
            return $this->node->value;
    }


    private static function text_(&$node) {
        if ($node->hasChildren()) {
            $value = null;
            foreach ($node->child as $child)
                $value .= MicroparserNode::text_(&$child);
            return $value;
        } else
            return $node->value;
    }

}


?>
