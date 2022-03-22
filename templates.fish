function select
  if type -q fzf
    string join \n $argv | fzf --height=10 --border=rounded --padding=0,1 --info=hidden --prompt="➡ " --marker="➡" --layout=reverse-list
  else
    while ! contains "$_selection" $argv
      string join "\n" $argv 1>&2
      read -P "Enter choice from list above: " _selection
      echo "$_selection"
    end
  end
end

function get_templates
  set _template_repos (gh repo list --topic template --json name,sshUrl -q '.[] | [.name, .sshUrl] | @tsv')
  for _template in $_template_repos
    set _url (echo $_template | cut -f2)
    set _name (echo $_template | cut -f1)
    set _template_branches (git ls-remote $_url 'refs/heads/*' | cut -f2 | sed 's|^refs/heads/||' | grep -E '^template-')
    for _template_branch in $_template_branches
      echo $_name\t$_url\t$_template_branch
    end
  end
end

function get_template_names
  for _template in $argv
    echo (echo $_template | cut -f1)\t(echo $_template | cut -f3)
  end
end

function get_template_urls
  for _template in $argv
    echo $_template | cut -f2 | sed 's|.*:|git+ssh://git@github.com/|'
  end
end

function get_template_branches
  for _template in $argv
    echo $_template | cut -f3
  end
end

function get_template_selection
  set _templates (get_templates)
  set _template_branches (get_template_branches $_templates)
  set _template_urls (get_template_urls $_templates)
  set _template_names (get_template_names $_templates)
  set _template_suggestions

  for i in (seq (count $_template_names))
    set _template_suggestions $_template_suggestions $i\t$_template_names[$i]
  end

  set _chosen (select $_template_suggestions | cut -f1)
  set _template_url $_template_urls[$_chosen]
  set _template_branch $_template_branches[$_chosen]
  echo $_template_url\t$_template_branch
end
